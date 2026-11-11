require 'json'
require 'open3'
require 'timeout'

module Praxo
  module Adapters
    # Minimal MCP stdio JSON-RPC client.
    class MCPClient
      DEFAULT_PROTOCOL_VERSION = '2024-11-05'

      attr_reader :protocol_version, :server_info

      def initialize(command: nil, args: [], env: {}, timeout: 5, reader: nil, writer: nil)
        @command = command
        @args = args
        @env = env
        @timeout = timeout
        @reader = reader
        @writer = writer
        @next_id = 0
        @closed = false
        @connected = false
      end

      def start
        return self if @connected

        if @reader.nil? || @writer.nil?
          raise Praxo::Error.new('MCP_TRANSPORT', 'mcp: command is required') if @command.nil?

          @stdin, @stdout, @stderr, @wait = Open3.popen3(@env, @command, *@args)
          @writer = @stdin
          @reader = @stdout
        end
        result = request('initialize', {
          protocolVersion: DEFAULT_PROTOCOL_VERSION,
          capabilities: {},
          clientInfo: { name: 'praxo-core', version: '0.4.1' }
        })
        version = result.is_a?(Hash) ? result['protocolVersion'] : nil
        if version.nil? || version.empty?
          raise Praxo::Error.new('MCP_HANDSHAKE', 'mcp: initialize returned no protocol version')
        end
        @protocol_version = version
        @server_info = result['serverInfo'] || {}
        notify('notifications/initialized', {})
        @connected = true
        self
      end

      def list_tools
        ensure_connected!
        tools = []
        names = {}
        cursor = nil
        seen_cursors = {}
        loop do
          params = cursor.nil? ? {} : { cursor: cursor }
          result = request('tools/list', params)
          list = result.is_a?(Hash) ? Array(result['tools']) : []
          list.each do |tool|
            name = tool['name'].to_s
            raise Praxo::Error.new('MCP_DUPLICATE_TOOL', "mcp: duplicate tool #{name}") if names[name]
            names[name] = true
            tools << tool
          end
          cursor = result['nextCursor'] if result.is_a?(Hash)
          break if cursor.nil? || cursor.to_s.empty?
          if seen_cursors[cursor]
            raise Praxo::Error.new('MCP_PAGINATION', 'mcp: repeated cursor')
          end
          seen_cursors[cursor] = true
        end
        tools
      end

      def call_tool(name, arguments = {}, timeout: nil)
        ensure_connected!
        result = request('tools/call', { name: name, arguments: arguments }, timeout: timeout)
        if result.is_a?(Hash) && result['isError']
          raise Praxo::Error.new('MCP_TOOL_ERROR', "mcp: tool #{name} failed")
        end
        structured = result.is_a?(Hash) ? result['structuredContent'] : nil
        return structured unless structured.nil?

        content = result.is_a?(Hash) ? Array(result['content']) : []
        texts = content.filter_map { |item| item['text'] if item['type'] == 'text' }
        texts.empty? ? nil : (texts.length == 1 ? texts.first : texts)
      end

      def close
        return if @closed

        @closed = true
        begin
          @writer.close if @writer && !@writer.closed?
        rescue IOError
          nil
        end
        begin
          @reader.close if @reader && !@reader.closed?
        rescue IOError
          nil
        end
        if @wait
          begin
            Process.kill('TERM', @wait.pid)
          rescue Errno::ESRCH
            nil
          end
          begin
            @wait.value
          rescue StandardError
            nil
          end
        end
      rescue StandardError
        nil
      ensure
        @connected = false
      end

      private

      def request(method, params, timeout: nil)
        raise Praxo::Error.new('MCP_CLOSED', 'mcp: client is closed') if @closed

        @next_id += 1
        id = @next_id
        write({ jsonrpc: '2.0', id: id, method: method, params: params })
        deadline = Time.now + (timeout || @timeout)
        loop do
          remaining = deadline - Time.now
          if remaining <= 0
            notify('notifications/cancelled', { requestId: id, reason: 'timeout' })
            raise Praxo::Error.new('MCP_TIMEOUT', "mcp: #{method} timed out")
          end
          readable = IO.select([@reader], nil, nil, remaining)
          raise Praxo::Error.new('MCP_TIMEOUT', "mcp: #{method} timed out") unless readable

          line = @reader.gets
          raise Praxo::Error.new('MCP_CLOSED', 'mcp: server closed the stream') if line.nil?

          begin
            message = JSON.parse(line)
          rescue JSON::ParserError
            raise Praxo::Error.new('MCP_PROTOCOL', 'mcp: invalid JSON from server')
          end
          next unless message['id'] == id
          if message['error']
            error = message['error']
            raise Praxo::Error.new('MCP_RPC', "mcp: #{error['message'] || 'rpc error'}")
          end
          return message['result']
        end
      end

      def notify(method, params)
        return if @closed

        write({ jsonrpc: '2.0', method: method, params: params })
      end

      def write(message)
        raise Praxo::Error.new('MCP_CLOSED', 'mcp: client is closed') if @writer.nil? || @writer.closed?

        @writer.puts(JSON.generate(message))
        @writer.flush
      rescue IOError, Errno::EPIPE
        raise Praxo::Error.new('MCP_TRANSPORT', 'mcp: write failed')
      end

      def ensure_connected!
        start unless @connected
      end
    end
  end
end
