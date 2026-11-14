require 'praxo'

class FakeTransport
  def request(method, _params, timeout: nil)
    case method
    when 'initialize'
      {
        'protocolVersion' => '2024-11-05',
        'capabilities' => { 'tools' => {} },
        'serverInfo' => { 'name' => 'example-mcp', 'version' => '1.0.0' }
      }
    when 'tools/list'
      { 'tools' => tools }
    when 'tools/call'
      { 'structuredContent' => { 'sum' => 5 } }
    else
      raise Praxo::Error.new('MCP_RPC', "mcp: #{method} failed")
    end
  end

  def notify(_method, _params); end

  def close; end

  private

  def tools
    [
      { 'name' => 'echo', 'description' => 'Echo input', 'inputSchema' => { 'type' => 'object' } },
      { 'name' => 'add', 'description' => 'Add two integers', 'inputSchema' => { 'type' => 'object' } }
    ]
  end
end

client = Praxo::Adapters::MCPClient.new(transport: FakeTransport.new).start
tools = client.list_tools
result = client.call_tool('add', { 'a' => 2, 'b' => 3 })
client.close

raise "unexpected tools: #{tools.inspect}" unless tools.map { |tool| tool['name'] } == %w[echo add]
raise "unexpected result: #{result.inspect}" unless result == { 'sum' => 5 }

puts 'Ruby MCP example passed'
