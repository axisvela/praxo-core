require 'json'
require 'net/http'
require 'uri'

module Praxo
  module Adapters
    # Streamable HTTP MCP transport (2025-03-26).
    class HttpMCPTransport
      def initialize(endpoint, headers: {}, protocol_version: '2025-03-26', timeout: 30)
        @uri = URI.parse(endpoint)
        unless %w[http https].include?(@uri.scheme)
          raise Praxo::Error.new('MCP_TRANSPORT', 'mcp: invalid HTTP endpoint')
        end
        if @uri.scheme == 'http' && !self.class.loopback?(@uri.host)
          raise Praxo::Error.new('MCP_TRANSPORT', 'mcp: HTTP endpoint must use HTTPS')
        end

        @headers = headers
        @protocol_version = protocol_version
        @timeout = timeout
        @session_id = ''
        @next_id = 0
        @closed = false
      end

      def request(method, params, timeout: nil)
        raise Praxo::Error.new('MCP_CLOSED', 'mcp: client is closed') if @closed

        @next_id += 1
        message = {
          jsonrpc: '2.0',
          id: @next_id,
          method: method,
          params: params
        }
        response = post(message, timeout || @timeout)
        if response['error']
          detail = response['error'].is_a?(Hash) ? response['error']['message'] : 'JSON-RPC error'
          raise Praxo::Error.new('MCP_RPC', "mcp: #{method} failed: #{detail}")
        end
        result = response['result'] || {}
        unless result.is_a?(Hash)
          raise Praxo::Error.new('MCP_PROTOCOL', "mcp: #{method} result must be an object")
        end
        result
      end

      def notify(method, params)
        return if @closed

        post({ jsonrpc: '2.0', method: method, params: params }, @timeout)
      end

      def close
        return if @closed

        @closed = true
        return if @session_id.empty?

        begin
          request = Net::HTTP::Delete.new(@uri)
          apply_headers(request)
          Net::HTTP.start(
            @uri.host,
            @uri.port,
            use_ssl: @uri.scheme == 'https',
            read_timeout: @timeout
          ) { |http| http.request(request) }
        rescue StandardError
          nil
        end
      end

      def self.loopback?(host)
        value = host.to_s.downcase
        ['localhost', '127.0.0.1', '::1', '[::1]'].include?(value) || value.start_with?('127.')
      end

      private

      def post(message, timeout)
        request = Net::HTTP::Post.new(@uri)
        request.body = JSON.generate(message)
        apply_headers(request)
        response = Net::HTTP.start(
          @uri.host,
          @uri.port,
          use_ssl: @uri.scheme == 'https',
          read_timeout: timeout
        ) { |http| http.request(request) }
        session = response['mcp-session-id']
        @session_id = session unless session.nil? || session.empty?
        status = response.code.to_i
        body = response.body.to_s
        return {} if [202, 204].include?(status) || body.strip.empty?
        if status < 200 || status >= 300
          raise Praxo::Error.new('MCP_TRANSPORT', "mcp: HTTP #{status}: #{body[0, 512]}")
        end

        decoded = if response['content-type'].to_s.downcase.include?('text/event-stream')
                    parse_sse(body, message[:id] || message['id'])
                  else
                    parse_json(body, message[:id] || message['id'])
                  end
        version = decoded.dig('result', 'protocolVersion')
        @protocol_version = version if version.is_a?(String) && !version.empty?
        decoded
      end

      def apply_headers(request)
        request['Content-Type'] = 'application/json'
        request['Accept'] = 'application/json, text/event-stream'
        request['MCP-Protocol-Version'] = @protocol_version
        request['MCP-Session-Id'] = @session_id unless @session_id.empty?
        @headers.each { |key, value| request[key] = value }
      end

      def parse_json(body, id)
        decoded = JSON.parse(body)
        raise Praxo::Error.new('MCP_PROTOCOL', 'mcp: server sent invalid JSON') unless decoded.is_a?(Hash)

        decoded
      rescue JSON::ParserError
        raise Praxo::Error.new('MCP_PROTOCOL', 'mcp: server sent invalid JSON')
      end

      def parse_sse(body, id)
        messages = []
        data = []
        body.split(/\r\n|\n|\r/).each do |line|
          if line.empty?
            unless data.empty?
              messages << decode_message(data.join("\n"))
              data = []
            end
            next
          end
          next if line.start_with?(':')
          data << line[5..].to_s.lstrip if line.start_with?('data:')
        end
        messages << decode_message(data.join("\n")) unless data.empty?
        return messages.find { |item| item['id'] == id } || messages.first unless messages.empty?

        raise Praxo::Error.new('MCP_PROTOCOL', 'mcp: response contained no message')
      end

      def decode_message(text)
        decoded = JSON.parse(text)
        unless decoded.is_a?(Hash)
          raise Praxo::Error.new('MCP_PROTOCOL', 'mcp: server sent a non-object message')
        end
        decoded
      rescue JSON::ParserError
        raise Praxo::Error.new('MCP_PROTOCOL', 'mcp: server sent invalid SSE JSON')
      end
    end
  end
end
