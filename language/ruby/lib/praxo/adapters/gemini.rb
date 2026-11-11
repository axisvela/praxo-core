require 'net/http'
require 'uri'
require_relative '../models'
require_relative '../json'

module Praxo
  module Adapters
    # Gemini generateContent adapter with an injectable transport.
    class Gemini
      DEFAULT_BASE_URL = 'https://generativelanguage.googleapis.com'

      def initialize(base_url: DEFAULT_BASE_URL, model:, api_key: nil,
                     max_output_tokens: 0, transport: nil, timeout: 60)
        @base_url = base_url.to_s.sub(%r{/$}, '')
        @model = model
        @api_key = api_key
        @max_output_tokens = max_output_tokens
        @transport = transport
        @timeout = timeout
      end

      def generate(request)
        Praxo.error('MODEL_CONFIG', 'gemini: API key is required') unless @api_key && !@api_key.empty?
        Praxo.error('MODEL_CONFIG', 'gemini: model is required') unless @model && !@model.empty?

        payload = build_payload(request)
        path = "/v1beta/models/#{URI.encode_www_form_component(@model)}:generateContent"
        data = @transport ? @transport.call(path, payload) : post(path, payload)
        parse_response(data)
      end

      private

      def build_payload(request)
        system, contents = build_contents(request.messages)
        payload = { contents: contents }
        payload[:system_instruction] = { parts: system } unless system.empty?
        tools = Array(request.tools).map do |tool|
          {
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters || { type: 'object', properties: {} }
          }
        end
        unless tools.empty?
          payload[:tools] = [{ functionDeclarations: tools }]
          payload[:toolConfig] = {
            functionCallingConfig: { mode: tool_mode(request.tool_choice) }
          }
        end
        if (request.temperature && request.temperature != 0) || @max_output_tokens.to_i.positive?
          payload[:generationConfig] = {
            temperature: request.temperature || 0,
            maxOutputTokens: @max_output_tokens
          }
        end
        payload
      end

      def build_contents(messages)
        system = []
        out = []
        pending = []
        names = {}
        flush = lambda do
          unless pending.empty?
            out << { role: 'user', parts: pending.dup }
            pending.clear
          end
        end
        Array(messages).each do |message|
          if message.role == Models::SYSTEM
            system << { text: message.content } if message.content && !message.content.empty?
            next
          end
          if message.role == Models::TOOL
            name = names[message.tool_id] || message.tool_id || 'tool'
            pending << {
              functionResponse: {
                name: name,
                response: { result: message.content || '' }
              }
            }
            next
          end
          flush.call
          parts = message_parts(message)
          unless parts.empty?
            out << {
              role: message.role == Models::ASSISTANT ? 'model' : 'user',
              parts: parts
            }
          end
          Array(message.tool_calls).each do |call|
            names[call.id] = call.name if call.id && !call.id.empty? && call.name && !call.name.empty?
          end
        end
        flush.call
        [system, out]
      end

      def message_parts(message)
        parts = []
        parts << { text: message.content } if message.content && !message.content.empty?
        Array(message.content_blocks).each do |block|
          if block.type == 'text' && block.text && !block.text.empty?
            parts << { text: block.text }
          end
        end
        Array(message.tool_calls).each do |call|
          parts << { functionCall: { name: call.name, args: call.arguments || {} } }
        end
        parts
      end

      def tool_mode(choice)
        case choice
        when 'required' then 'ANY'
        when 'none' then 'NONE'
        else 'AUTO'
        end
      end

      def parse_response(data)
        Praxo.error('MODEL_HTTP', "gemini: #{data['error']['message']}") if data['error']

        candidate = Array(data['candidates']).first
        Praxo.error('MODEL_HTTP', 'gemini: empty response') unless candidate

        text = +''
        calls = []
        Array((candidate['content'] || {})['parts']).each do |part|
          text << part['text'].to_s if part['text']
          call = part['functionCall']
          next unless call

          calls << Models.tool_call(
            id: "call-#{calls.length + 1}",
            name: call['name'] || '',
            arguments: call['args'] || {}
          )
        end
        usage = data['usageMetadata'] || {}
        Models.response(
          message: Models.message(
            role: Models::ASSISTANT,
            content: text,
            tool_calls: calls
          ),
          usage: Models.usage(
            input_tokens: usage['promptTokenCount'].to_i,
            output_tokens: usage['candidatesTokenCount'].to_i,
            cached_tokens: usage['cachedContentTokenCount'].to_i
          ),
          finish_reason: candidate['finishReason']
        )
      end

      def post(path, payload)
        uri = URI.join(@base_url + '/', path.sub(%r{^/}, ''))
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['x-goog-api-key'] = @api_key
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
