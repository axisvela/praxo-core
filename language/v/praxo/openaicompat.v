module praxo

import net.http
import x.json2

pub type Transport = fn (base_url string, api_key string, path string, payload map[string]json2.Any) !map[string]json2.Any

fn openai_default_transport(base_url string, api_key string, path string, payload map[string]json2.Any) !map[string]json2.Any {
	if base_url == '' {
		return praxo_error('PROVIDER_HTTP', 'provider base URL is required')
	}
	mut headers := http.new_header(key: .content_type, value: 'application/json')
	if api_key != '' {
		headers.add(.authorization, 'Bearer ${api_key}')
	}
	response := http.fetch(
		url: base_url + path
		method: .post
		data: encode_json(json2.Any(payload))
		header: headers
	) or {
		return praxo_error('PROVIDER_HTTP', 'provider request failed: ${err.msg()}')
	}
	if response.status_code < 200 || response.status_code >= 300 {
		detail := if response.body.len > 512 { response.body[..512] } else { response.body }
		return praxo_error('PROVIDER_HTTP', 'provider returned HTTP ${response.status_code}: ${detail}')
	}
	data := parse_json(response.body) or {
		return praxo_error('PROVIDER_JSON', 'provider returned invalid JSON')
	}
	return as_object(data)
}

@[heap]
pub struct OpenAICompatible {
pub mut:
	base_url  string
	model     string
	api_key   string
	transport Transport = openai_default_transport
	timeout   int
}

pub struct OpenAIOptions {
pub:
	api_key   string
	transport Transport = openai_default_transport
	timeout   int
}

pub fn openai_compatible(base_url string, model string) &OpenAICompatible {
	return openai_compatible_with_options(base_url, model, OpenAIOptions{})
}

pub fn openai_compatible_with_options(base_url string, model string, options OpenAIOptions) &OpenAICompatible {
	return &OpenAICompatible{
		base_url: base_url.trim_right('/')
		model: model
		api_key: options.api_key
		transport: options.transport
		timeout: if options.timeout > 0 { options.timeout } else { 60 }
	}
}

pub fn openai_compatible_model(adapter &OpenAICompatible) &Model {
	return callback_model(fn [adapter] (request Request) !Response {
		return adapter.generate(request)
	})
}

fn openai_message(message Message) map[string]json2.Any {
	mut content := message.content
	if content == '' && message.content_blocks.len > 0 {
		mut parts := []string{}
		for block in message.content_blocks {
			if block.kind == 'text' {
				parts << block.text
			}
		}
		content = parts.join('')
	}
	mut out := map[string]json2.Any{}
	out['role'] = json2.Any(message.role)
	out['content'] = json2.Any(content)
	if message.role == role_assistant && message.tool_calls.len > 0 {
		mut calls := []json2.Any{cap: message.tool_calls.len}
		for call in message.tool_calls {
			mut function_value := map[string]json2.Any{}
			function_value['name'] = json2.Any(call.name)
			function_value['arguments'] = json2.Any(encode_json(json2.Any(call.arguments)))
			mut call_value := map[string]json2.Any{}
			call_value['id'] = json2.Any(call.id)
			call_value['type'] = json2.Any('function')
			call_value['function'] = json2.Any(function_value)
			calls << json2.Any(call_value)
		}
		out['tool_calls'] = json2.Any(calls)
	}
	if message.role == role_tool && message.tool_id != '' {
		out['tool_call_id'] = json2.Any(message.tool_id)
	}
	return out
}

fn openai_tool(tool ToolSpec) map[string]json2.Any {
	mut parameters := map[string]json2.Any{}
	parameters['type'] = json2.Any('object')
	mut function_value := map[string]json2.Any{}
	function_value['name'] = json2.Any(tool.name)
	function_value['description'] = json2.Any(tool.description)
	function_value['parameters'] = json2.Any(parameters)
	mut out := map[string]json2.Any{}
	out['type'] = json2.Any('function')
	out['function'] = json2.Any(function_value)
	return out
}

fn openai_payload(adapter &OpenAICompatible, request Request) map[string]json2.Any {
	mut messages := []json2.Any{cap: request.messages.len}
	for message in request.messages {
		messages << json2.Any(openai_message(message))
	}
	mut payload := map[string]json2.Any{}
	payload['model'] = json2.Any(adapter.model)
	payload['messages'] = json2.Any(messages)
	if request.tools.len > 0 {
		mut tools := []json2.Any{cap: request.tools.len}
		for tool in request.tools {
			tools << json2.Any(openai_tool(tool))
		}
		payload['tools'] = json2.Any(tools)
	}
	if request.tool_choice != '' {
		payload['tool_choice'] = json2.Any(request.tool_choice)
	}
	return payload
}

fn openai_parse_response(data map[string]json2.Any) !Response {
	choices := get_array(data, 'choices')
	mut choice := map[string]json2.Any{}
	if choices.len > 0 {
		choice = as_object(choices[0])
	}
	message := get_object(choice, 'message')
	mut calls := []ToolCall{}
	for item in get_array(message, 'tool_calls') {
		call_value := as_object(item)
		function_value := get_object(call_value, 'function')
		id := get_string(call_value, 'id') or { '' }
		name := get_string(function_value, 'name') or { '' }
		raw := get(function_value, 'arguments') or { json2.Any('') }
		mut arguments := map[string]json2.Any{}
		if raw is string {
			text := raw as string
			if text != '' {
				parsed := parse_json(text) or {
					return praxo_error('PROVIDER_JSON', 'provider returned invalid tool arguments')
				}
				if parsed is map[string]json2.Any {
					arguments = parsed as map[string]json2.Any
				} else {
					return praxo_error('PROVIDER_JSON', 'provider tool arguments must be an object')
				}
			}
		} else if raw is map[string]json2.Any {
			arguments = raw as map[string]json2.Any
		}
		calls << tool_call(id, name, arguments)
	}
	content := get_string(message, 'content') or { '' }
	usage_value := get_object(data, 'usage')
	input_tokens := get_int(usage_value, 'prompt_tokens', 0)
	output_tokens := get_int(usage_value, 'completion_tokens', 0)
	return Response{
		message: message_assistant(content, calls)
		usage: usage(input_tokens, output_tokens)
	}
}

pub fn (adapter &OpenAICompatible) generate(request Request) !Response {
	if adapter.base_url == '' {
		return praxo_error('PROVIDER_HTTP', 'provider base URL is required')
	}
	payload := openai_payload(adapter, request)
	path := '/chat/completions'
	data := adapter.transport(adapter.base_url, adapter.api_key, path, payload)!
	return openai_parse_response(data)
}
