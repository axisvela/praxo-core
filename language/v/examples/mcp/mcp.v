module main

import praxo
import x.json2

fn transport(method string, params map[string]json2.Any) !map[string]json2.Any {
	if method == 'initialize' {
		return json2.decode[map[string]json2.Any]('{"protocolVersion":"2024-11-05","serverInfo":{"name":"example-mcp"}}')!
	}
	if method == 'tools/list' {
		return json2.decode[map[string]json2.Any]('{"tools":[{"name":"echo","inputSchema":{"type":"object"}},{"name":"add","inputSchema":{"type":"object"}}]}')!
	}
	if method == 'tools/call' {
		return json2.decode[map[string]json2.Any]('{"structuredContent":{"sum":5}}')!
	}
	return map[string]json2.Any{}
}

fn main() {
	mut client := praxo.mcp_client(praxo.McpOptions{ transport: transport }) or { panic(err) }
	tools := client.list_tools() or { panic(err) }
	value := client.call_tool('add', map[string]json2.Any{}) or { panic(err) }
	client.close()
	assert tools.len == 2
	assert (praxo.as_int(value) or { 0 }) == 5
	println('V MCP example passed')
}
