require 'net/http'
require 'uri'
require_relative '../models'
require_relative '../json'
require_relative '../errors'

module Praxo
  module Adapters
    # Anthropic Messages adapter with an injectable transport.
    class Anthropic
      DEFAULT_BASE_URL = 'https://api.anthropic.com'
      DEFAULT_VERSION = '2023-06-01'

      def initialize(base_url: DEFAULT_BASE_URL, model:, api_key: nil, version: DEFAULT_VERSION,
                     max_tokens: 1024, transport: nil, stream_transport: nil, timeout: 60)
        @base_url = base_url.to_s.sub(%r{/$}, '')
        @model = model
        @api_key = api_key
        @version = version
        @max_tokens = max_tokens
        @transport = transport
        @stream_transport = stream_transport
        @timeout = timeout
      end

      def generate_stream(request, on_delta)
        Praxo.error('MODEL_CONFIG', 'anthropic: API key is required') unless @api_key && !@api_key.empty?
        Praxo.error('MODEL_CONFIG', 'anthropic: model is required') unless @model && !@model.empty?

        payload = build_payload(request, true)
        text = @stream_transport ? @stream_transport.call('/v1/messages', payload) : post_stream(payload)
        parse_stream(text, on_delta)
      end

      def generate(request)
        Praxo.error('MODEL_CONFIG', 'anthropic: API key is required') unless @api_key && !@api_key.empty?
        Praxo.error('MODEL_CONFIG', 'anthropic: model is required') unless @model && !@model.empty?

        payload = build_payload(request)
        data = @transport ? @transport.call('/v1/messages', payload) : post(payload)
        parse_response(data)
      end

      private

      def build_payload(request, stream = false)
        system, messages = build_messages(request.messages)
        payload = {
          model: @model,
          max_tokens: @max_tokens,
          messages: messages
        }
        payload[:system] = system unless system.empty?
        tools = Array(request.tools).map do |tool|
          {
            name: tool.name,
            description: tool.description,
            input_schema: tool.parameters || { type: 'object', properties: {} }
          }
        end
        unless tools.empty?
          payload[:tools] = tools
          choice = tool_choice(request.tool_choice)
          payload[:tool_choice] = choice if choice
        end
        payload[:temperature] = request.temperature if request.temperature
        payload[:stream] = true if stream
        payload
      end

      def build_messages(messages)
        system = []
        out = []
        pending = []
        flush = lambda do
          unless pending.empty?
            out << { role: 'user', content: pending.dup }
            pending.clear
          end
        end
        Array(messages).each do |message|
          if message.role == Models::SYSTEM
            system << message.content if message.content && !message.content.empty?
            next
          end
          if message.role == Models::TOOL
            pending << {
              type: 'tool_result',
              tool_use_id: message.tool_id || '',
              content: message.content || ''
            }
            next
          end
          flush.call
          content = message_content(message)
          out << { role: message.role, content: content } unless content.empty?
        end
        flush.call
        [system.join("\n\n"), out]
      end

      def message_content(message)
        content = []
        content << { type: 'text', text: message.content } if message.content && !message.content.empty?
        Array(message.content_blocks).each do |block|
          if block.type == 'text' && block.text && !block.text.empty?
            content << { type: 'text', text: block.text }
          end
        end
        Array(message.tool_calls).each do |call|
          content << {
            type: 'tool_use',
            id: call.id,
            name: call.name,
            input: call.arguments || {}
          }
        end
        content
      end

      def tool_choice(choice)
        case choice
        when 'auto' then { type: 'auto' }
        when 'required' then { type: 'any' }
        when 'none' then { type: 'none' }
        end
      end

      def parse_stream(text, on_delta)
        content = +''
        calls = {}
        input_tokens = 0
        output_tokens = 0
        cached_tokens = 0
        stop_reason = nil
        stopped = false
        text.to_s.each_line do |raw|
          line = raw.strip
          next unless line.start_with?('data:')
          chunk = line[5..].to_s.strip
          next if chunk.empty?
          event = begin
            Json.parse(chunk)
          rescue StandardError
            Praxo.error('MODEL_STREAM', 'anthropic: invalid stream chunk')
          end
          next unless event.is_a?(Hash)

          case event['type']
          when 'message_start'
            usage = (event['message'] || {})['usage'] || {}
            input_tokens = usage['input_tokens'].to_i
            cached_tokens = usage['cache_read_input_tokens'].to_i
          when 'content_block_start'
            index = event['index'].to_i
            block = event['content_block'] || {}
            if block['type'] == 'tool_use'
              calls[index] = { id: block['id'].to_s, name: block['name'].to_s, arguments: +'' }
            end
          when 'content_block_delta'
            index = event['index'].to_i
            delta = event['delta'] || {}
            case delta['type']
            when 'text_delta'
              piece = delta['text'].to_s
              unless piece.empty?
                content << piece
                on_delta.call(piece)
              end
            when 'input_json_delta'
              if calls[index]
                calls[index][:arguments] << delta['partial_json'].to_s
              end
            end
          when 'message_delta'
            stop_reason = (event['delta'] || {})['stop_reason'] || stop_reason
            output_tokens = (event['usage'] || {})['output_tokens'] || output_tokens
          when 'message_stop'
            stopped = true
          when 'error'
            Praxo.error('MODEL_STREAM', 'anthropic: stream error')
          end
        end
        Praxo.error('MODEL_STREAM', 'anthropic: stream ended before completion') unless stopped || stop_reason
        tool_calls = calls.keys.sort.filter_map do |index|
          call = calls[index]
          next if call[:name].empty?

          arguments = {}
          unless call[:arguments].empty?
            begin
              arguments = Json.parse(call[:arguments])
            rescue StandardError
              Praxo.error('PROVIDER_JSON', 'anthropic: invalid tool arguments')
            end
            unless arguments.is_a?(Hash)
              Praxo.error('PROVIDER_JSON', 'anthropic: invalid tool arguments')
            end
          end
          Models.tool_call(id: call[:id], name: call[:name], arguments: arguments)
        end
        result = Models.response(
          message: Models.message(role: Models::ASSISTANT, content: content,
                                  tool_calls: tool_calls),
          usage: Models.usage(input_tokens: input_tokens, output_tokens: output_tokens)
        )
        result.usage.cached_tokens = cached_tokens if result.usage.respond_to?(:cached_tokens=)
        result.finish_reason = stop_reason if result.respond_to?(:finish_reason=)
        result
      end

      def parse_response(data)
        Praxo.error('MODEL_HTTP', "anthropic: #{data['error']['message']}") if data['error']

        text = +''
        calls = []
        Array(data['content']).each do |block|
          case block['type']
          when 'text'
            text << block['text'].to_s
          when 'tool_use'
            calls << Models.tool_call(
              id: block['id'] || "call-#{calls.length + 1}",
              name: block['name'] || '',
              arguments: block['input'] || {}
            )
          end
        end
        usage = data['usage'] || {}
        Models.response(
          message: Models.message(
            role: Models::ASSISTANT,
            content: text,
            tool_calls: calls
          ),
          usage: Models.usage(
            input_tokens: usage['input_tokens'].to_i,
            output_tokens: usage['output_tokens'].to_i,
            cached_tokens: usage['cache_read_input_tokens'].to_i
          ),
          finish_reason: data['stop_reason']
        )
      end

      def post_stream(payload)
        uri = URI.join(@base_url + '/', 'v1/messages')
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Accept'] = 'text/event-stream'
        request['x-api-key'] = @api_key if @api_key
        request['anthropic-version'] = @version
        request.body = Json.stringify(payload)
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == 'https',
          read_timeout: @timeout
        ) { |http| http.request(request) }
        body = response.body.to_s
        unless response.is_a?(Net::HTTPSuccess)
          Praxo.error('PROVIDER_HTTP', "provider returned HTTP #{response.code}: #{body}")
        end
        body
      end

      def post(payload)
        uri = URI.join(@base_url + '/', 'v1/messages')
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['x-api-key'] = @api_key
        request['anthropic-version'] = @version
        request.body = Json.stringify(payload)
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == 'https',
          read_timeout: @timeout
        ) { |http| http.request(request) }
        body = response.body.to_s
        unless response.is_a?(Net::HTTPSuccess)
          Praxo.error('PROVIDER_HTTP', "provider returned HTTP #{response.code}: #{body}")
        end
        Json.parse(body)
      end
    end
  end
end
