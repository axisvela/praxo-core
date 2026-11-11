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
                     max_tokens: 1024, transport: nil, timeout: 60)
        @base_url = base_url.to_s.sub(%r{/$}, '')
        @model = model
        @api_key = api_key
        @version = version
        @max_tokens = max_tokens
        @transport = transport
        @timeout = timeout
      end

      def generate(request)
        Praxo.error('MODEL_CONFIG', 'anthropic: API key is required') unless @api_key && !@api_key.empty?
        Praxo.error('MODEL_CONFIG', 'anthropic: model is required') unless @model && !@model.empty?

        payload = build_payload(request)
        data = @transport ? @transport.call('/v1/messages', payload) : post(payload)
        parse_response(data)
      end

      private

      def build_payload(request)
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
