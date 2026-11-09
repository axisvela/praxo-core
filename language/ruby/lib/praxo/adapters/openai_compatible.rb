require 'net/http'
require 'uri'
require_relative '../models'
require_relative '../json'
require_relative '../errors'

module Praxo
  module Adapters
    # OpenAI-compatible chat completions adapter.
    #
    # transport is injectable for deterministic tests:
    #   ->(path, payload) { parsed_response_hash }
    class OpenAICompatible
      def initialize(base_url:, model:, api_key: nil, transport: nil, timeout: 60)
        @base_url = base_url.to_s.sub(%r{/$}, '')
        @model = model
        @api_key = api_key
        @transport = transport
        @timeout = timeout
      end

      def generate(request)
        payload = build_payload(request)
        data = @transport ? @transport.call('/chat/completions', payload) : post('/chat/completions', payload)
        parse_response(data)
      end

      private

      def build_payload(request)
        payload = {
          model: @model,
          messages: Array(request.messages).map { |message| message_payload(message) }
        }
        tools = Array(request.tools).map do |tool|
          {
            type: 'function',
            function: {
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters || { type: 'object' }
            }
          }
        end
        payload[:tools] = tools unless tools.empty?
        payload[:tool_choice] = request.tool_choice if request.tool_choice
        payload[:temperature] = request.temperature if request.temperature
        payload[:response_format] = request.response_format if request.response_format
        payload
      end

      def message_payload(message)
        content = message.content
        if (content.nil? || content.empty?) && !Array(message.content_blocks).empty?
          content = Array(message.content_blocks)
                    .select { |block| block.type == 'text' && block.text }
                    .map(&:text)
                    .join
        end
        out = { role: message.role, content: content }
        if message.role == Models::ASSISTANT && !Array(message.tool_calls).empty?
          out[:tool_calls] = Array(message.tool_calls).map do |call|
            {
              id: call.id,
              type: 'function',
              function: {
                name: call.name,
                arguments: Json.stringify(call.arguments || {})
              }
            }
          end
        end
        out[:tool_call_id] = message.tool_id if message.role == Models::TOOL && message.tool_id
        out
      end

      def parse_response(data)
        choice = Array(data['choices']).first || {}
        message = choice['message'] || {}
        tool_calls = Array(message['tool_calls']).map do |call|
          function = call['function'] || {}
          arguments = function['arguments']
          arguments = Json.parse(arguments) if arguments.is_a?(String) && !arguments.empty?
          Models.tool_call(id: call['id'], name: function['name'], arguments: arguments || {})
        end
        usage = data['usage'] || {}
        Models.response(
          message: Models.message(
            role: Models::ASSISTANT,
            content: message['content'],
            tool_calls: tool_calls
          ),
          usage: Models.usage(
            input_tokens: usage['prompt_tokens'].to_i,
            output_tokens: usage['completion_tokens'].to_i
          ),
          finish_reason: choice['finish_reason']
        )
      end

      def post(path, payload)
        uri = URI.join(@base_url + '/', path.sub(%r{^/}, ''))
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{@api_key}" if @api_key
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
