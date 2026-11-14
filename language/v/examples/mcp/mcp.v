module main

import praxo

fn transport(method string, params map[string]json2.Any) !map[string]json2.Any {
	if method == 'initialize' {
		return {
			'protocolVersion': json2.Any('2024-11-05')
			'serverInfo':      json2.Any(map[string]json2.Any{'name': json2.Any('example-mcp')})
		}
	}
	if method == 'tools/list' {
		schema := map[string]json2.Any{'type': json2.Any('object')}
		return {
			'tools': json2.Any([
				map[string]json2.Any{'name': json2.Any('echo'), 'inputSchema': json2.Any(schema)}
				map[string]json2.Any{'name': json2.Any('add'), 'inputSchema': json2.Any(schema)}
			])
		}
	}
	if method == 'tools/call' {
		return {
			'structuredContent': json2.Any(map[string]json2.Any{'sum': json2.Any(5)})
		}
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
