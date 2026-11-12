module praxo

import x.json2

pub type McpTransport = fn (method string, params map[string]json2.Any) !map[string]json2.Any

pub struct McpOptions {
pub:
	transport        McpTransport
	client_version   string = '0.3.0'
	protocol_version string = '2024-11-05'
}

@[heap]
pub struct McpClient {
pub mut:
	transport        McpTransport
	client_version   string
	protocol_version string
	server_info      map[string]json2.Any
	closed           bool
}

pub fn mcp_client(options McpOptions) !&McpClient {
	mut client := &McpClient{
		transport: options.transport
		client_version: if options.client_version != '' {
			options.client_version
		} else {
			'0.3.0'
		}
		protocol_version: if options.protocol_version != '' {
			options.protocol_version
		} else {
			'2024-11-05'
		}
		server_info: map[string]json2.Any{}
	}
	result := client.transport('initialize', {
		'protocolVersion': json2.Any(client.protocol_version)
		'capabilities':    json2.Any(map[string]json2.Any{})
		'clientInfo': json2.Any(map[string]json2.Any{
			'name':    json2.Any('praxo-core')
			'version': json2.Any(client.client_version)
		})
	})!
	version := as_string(result['protocolVersion'] or { json2.Any('') }) or { '' }
	if version == '' {
		return praxo_error('MCP_HANDSHAKE', 'mcp: initialize returned no protocol version')
	}
	client.protocol_version = version
	client.server_info = as_object(result['serverInfo'] or {
		json2.Any(map[string]json2.Any{})
	})
	return client
}

pub fn (client &McpClient) list_tools() ![]map[string]json2.Any {
	mut tools := []map[string]json2.Any{}
	mut names := map[string]bool{}
	mut cursors := map[string]bool{}
	mut cursor := ''
	for {
		mut params := map[string]json2.Any{}
		if cursor != '' {
			params['cursor'] = json2.Any(cursor)
		}
		result := client.transport('tools/list', params)!
		for item in as_array(result['tools'] or { json2.Any([]json2.Any{}) }) {
			tool := as_object(item)
			name := as_string(tool['name'] or { json2.Any('') }) or { '' }
			if name == '' {
				return praxo_error('MCP_PROTOCOL', 'mcp: tool name is required')
			}
			if names[name] {
				return praxo_error('MCP_DUPLICATE_TOOL', 'mcp: duplicate tool ${name}')
			}
			names[name] = true
			tools << tool
		}
		next := as_string(result['nextCursor'] or { json2.Any('') }) or { '' }
		if next == '' {
			break
		}
		if cursors[next] {
			return praxo_error('MCP_PAGINATION', 'mcp: repeated tool pagination cursor')
		}
		cursors[next] = true
		cursor = next
	}
	return tools
}

pub fn (client &McpClient) call_tool(name string, arguments map[string]json2.Any) !json2.Any {
	result := client.transport('tools/call', {
		'name':      json2.Any(name)
		'arguments': json2.Any(arguments)
	})!
	if as_bool(result['isError'] or { json2.Any(false) }) or { false } {
		return praxo_error('MCP_TOOL_ERROR', 'mcp: tool ${name} failed')
	}
	if 'structuredContent' in result {
		return result['structuredContent']
	}
	mut texts := []string{}
	for item in as_array(result['content'] or { json2.Any([]json2.Any{}) }) {
		block := as_object(item)
		kind := as_string(block['type'] or { json2.Any('') }) or { '' }
		if kind == 'text' {
			texts << (as_string(block['text'] or { json2.Any('') }) or { '' })
		}
	}
	if texts.len == 0 {
		return json2.Any(json2.Null{})
	}
	if texts.len == 1 {
		return json2.Any(texts[0])
	}
	return json2.Any(texts)
}

pub fn (mut client McpClient) close() {
	client.closed = true
}
