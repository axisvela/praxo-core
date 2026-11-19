module praxo

import net.http
import x.json2

pub type AnthropicStreamTransport = fn (base_url string, api_key string, version string, path string, payload map[string]json2.Any) !string

fn anthropic_default_stream_transport(base_url string, api_key string, version string, path string, payload map[string]json2.Any) !string {
	if base_url == '' {
		return praxo_error('PROVIDER_HTTP', 'provider base URL is required')
	}
	mut headers := http.new_header(key: .content_type, value: 'application/json')
	headers.add(.accept, 'text/event-stream')
	mut custom := map[string]string{}
	custom['x-api-key'] = api_key
	custom['anthropic-version'] = version
	headers.add_custom_map(custom)!
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
	return response.body
}

@[heap]
pub struct AnthropicCompatible {
pub mut:
	base_url   string
	model      string
	api_key    string
	version    string = '2023-06-01'
	max_tokens int = 1024
	transport  ProviderTransport = provider_default_transport
	stream_transport AnthropicStreamTransport = anthropic_default_stream_transport
}

pub struct AnthropicOptions {
pub:
	api_key    string
	version    string
	max_tokens int
	transport  ProviderTransport = provider_default_transport
	stream_transport AnthropicStreamTransport = anthropic_default_stream_transport
}

pub fn anthropic_compatible(base_url string, model string) &AnthropicCompatible {
	return anthropic_compatible_with_options(base_url, model, AnthropicOptions{})
}

pub fn anthropic_compatible_with_options(base_url string, model string, options AnthropicOptions) &AnthropicCompatible {
	return &AnthropicCompatible{
		base_url: base_url.trim_right('/')
		model: model
		api_key: options.api_key
		version: if options.version != '' { options.version } else { '2023-06-01' }
		max_tokens: if options.max_tokens > 0 { options.max_tokens } else { 1024 }
		transport: options.transport
		stream_transport: options.stream_transport
	}
}

pub fn anthropic_compatible_model(adapter &AnthropicCompatible) &Model {
	return &Model{
		mode: 'callback'
		callback: fn [adapter] (request Request) !Response {
			return adapter.generate(request)
		}
		stream_callback: fn [adapter] (request Request, on_delta DeltaHandler) !Response {
			return adapter.generate_stream(request, on_delta)
		}
		has_stream: true
	}
}

fn anthropic_text_part(text string) json2.Any {
	mut part := map[string]json2.Any{}
	part['type'] = json2.Any('text')
	part['text'] = json2.Any(text)
	return json2.Any(part)
}

fn anthropic_content(message Message) []json2.Any {
	mut content := []json2.Any{}
	if message.content != '' {
		content << anthropic_text_part(message.content)
	}
	for block in message.content_blocks {
		if block.kind == 'text' && block.text != '' {
			content << anthropic_text_part(block.text)
		}
	}
	for call in message.tool_calls {
		mut part := map[string]json2.Any{}
		part['type'] = json2.Any('tool_use')
		part['id'] = json2.Any(call.id)
		part['name'] = json2.Any(call.name)
		part['input'] = json2.Any(call.arguments)
		content << json2.Any(part)
	}
	return content
}

fn anthropic_flush(mut messages []json2.Any, mut results []json2.Any) {
	if results.len == 0 {
		return
	}
	mut message := map[string]json2.Any{}
	message['role'] = json2.Any(role_user)
	message['content'] = json2.Any(results)
	messages << json2.Any(message)
	results.clear()
}

fn anthropic_payload(adapter &AnthropicCompatible, request Request) map[string]json2.Any {
	mut system := []string{}
	mut messages := []json2.Any{}
	mut tool_results := []json2.Any{}
	for message in request.messages {
		if message.role == role_system {
			if message.content != '' {
				system << message.content
			}
			continue
		}
		if message.role == role_tool {
			mut result := map[string]json2.Any{}
			result['type'] = json2.Any('tool_result')
			result['tool_use_id'] = json2.Any(message.tool_id)
			result['content'] = json2.Any(message.content)
			tool_results << json2.Any(result)
			continue
		}
		anthropic_flush(mut messages, mut tool_results)
		content := anthropic_content(message)
		if content.len > 0 {
			mut wire_message := map[string]json2.Any{}
			wire_message['role'] = json2.Any(message.role)
			wire_message['content'] = json2.Any(content)
			messages << json2.Any(wire_message)
		}
	}
	anthropic_flush(mut messages, mut tool_results)
	mut payload := map[string]json2.Any{}
	payload['model'] = json2.Any(adapter.model)
	payload['max_tokens'] = json2.Any(f64(adapter.max_tokens))
	payload['messages'] = json2.Any(messages)
	if system.len > 0 {
		payload['system'] = json2.Any(system.join('\n\n'))
	}
	if request.tools.len > 0 {
		mut tools := []json2.Any{cap: request.tools.len}
		for tool in request.tools {
			mut schema := map[string]json2.Any{}
			schema['type'] = json2.Any('object')
			mut properties := map[string]json2.Any{}
			schema['properties'] = json2.Any(properties)
			mut tool_value := map[string]json2.Any{}
			tool_value['name'] = json2.Any(tool.name)
			tool_value['description'] = json2.Any(tool.description)
			tool_value['input_schema'] = json2.Any(schema)
			tools << json2.Any(tool_value)
		}
		payload['tools'] = json2.Any(tools)
		if request.tool_choice != '' {
			mut choice := map[string]json2.Any{}
			choice['type'] = json2.Any(anthropic_choice(request.tool_choice))
			payload['tool_choice'] = json2.Any(choice)
		}
	}
	return payload
}

fn anthropic_choice(choice string) string {
	if choice == 'required' {
		return 'any'
	}
	if choice == 'none' {
		return 'none'
	}
	return 'auto'
}

fn anthropic_parse_response(data map[string]json2.Any) !Response {
	mut text := ''
	mut calls := []ToolCall{}
	for item in get_array(data, 'content') {
		block := as_object(item)
		kind := get_string(block, 'type') or { '' }
		if kind == 'text' {
			text += get_string(block, 'text') or { '' }
		} else if kind == 'tool_use' {
			calls << tool_call(
				get_string(block, 'id') or { '' },
				get_string(block, 'name') or { '' },
				as_object(get(block, 'input') or { json2.null })
			)
		}
	}
	usage_value := get_object(data, 'usage')
	return response(message_assistant(text, calls), usage(
		get_int(usage_value, 'input_tokens', 0),
		get_int(usage_value, 'output_tokens', 0)
	))
}

pub fn (adapter &AnthropicCompatible) generate(request Request) !Response {
	if adapter.api_key == '' {
		return praxo_error('MODEL_CONFIG', 'anthropic: API key is required')
	}
	if adapter.model == '' {
		return praxo_error('MODEL_CONFIG', 'anthropic: model is required')
	}
	payload := anthropic_payload(adapter, request)
	mut headers := map[string]string{}
	headers['x-api-key'] = adapter.api_key
	headers['anthropic-version'] = adapter.version
	data := adapter.transport(adapter.base_url, '/v1/messages', payload, headers)!
	return anthropic_parse_response(data)
}

fn anthropic_parse_sse(text string, on_delta DeltaHandler) !Response {
	mut content := ''
	mut input_tokens := 0
	mut output_tokens := 0
	mut cached_tokens := 0
	mut stop_reason := ''
	mut done := false
	mut calls := map[int]PartialCall{}
	for raw in text.split_into_lines() {
		line := raw.trim_space()
		if !line.starts_with('data:') {
			continue
		}
		chunk := line[5..].trim_space()
		if chunk == '' {
			continue
		}
		event := parse_json(chunk) or {
			return praxo_error('MODEL_STREAM', 'anthropic: invalid SSE packet')
		}
		if event !is map[string]json2.Any {
			continue
		}
		event_object := event as map[string]json2.Any
		kind := get_string(event_object, 'type') or { '' }
		if kind == 'message_start' {
			usage_value := get_object(get_object(event_object, 'message'), 'usage')
			input_tokens = get_int(usage_value, 'input_tokens', input_tokens)
			cached_tokens = get_int(usage_value, 'cache_read_input_tokens', cached_tokens)
		} else if kind == 'content_block_start' {
			index := get_int(event_object, 'index', calls.len)
			block := get_object(event_object, 'content_block')
			if get_string(block, 'type') or { '' } == 'tool_use' {
				calls[index] = PartialCall{
					id: get_string(block, 'id') or { '' }
					name: get_string(block, 'name') or { '' }
				}
			}
		} else if kind == 'content_block_delta' {
			index := get_int(event_object, 'index', 0)
			delta := get_object(event_object, 'delta')
			delta_type := get_string(delta, 'type') or { '' }
			if delta_type == 'text_delta' {
				piece := get_string(delta, 'text') or { '' }
				if piece != '' {
					content += piece
					on_delta(piece)
				}
			} else if delta_type == 'input_json_delta' {
				mut slot := calls[index] or { PartialCall{} }
				slot.arguments += get_string(delta, 'partial_json') or { '' }
				calls[index] = slot
			}
		} else if kind == 'message_delta' {
			delta := get_object(event_object, 'delta')
			reason := get_string(delta, 'stop_reason') or { '' }
			if reason != '' {
				stop_reason = reason
			}
			usage_value := get_object(event_object, 'usage')
			output_tokens = get_int(usage_value, 'output_tokens', output_tokens)
		} else if kind == 'message_stop' {
			done = true
		} else if kind == 'error' {
			return praxo_error('MODEL_STREAM', 'anthropic: provider stream error')
		}
	}
	if !done && stop_reason == '' {
		return praxo_error('MODEL_STREAM', 'stream ended before completion')
	}
	mut indexes := calls.keys()
	indexes.sort()
	mut tool_calls := []ToolCall{}
	for index in indexes {
		slot := calls[index]
		if slot.name == '' {
			continue
		}
		mut arguments := map[string]json2.Any{}
		if slot.arguments != '' {
			parsed := parse_json(slot.arguments) or {
				return praxo_error('PROVIDER_JSON', 'anthropic: invalid tool arguments')
			}
			if parsed is map[string]json2.Any {
				arguments = parsed as map[string]json2.Any
			} else {
				return praxo_error('PROVIDER_JSON', 'anthropic: tool arguments must be an object')
			}
		}
		tool_calls << tool_call(slot.id, slot.name, arguments)
	}
	return Response{
		message: message_assistant(content, tool_calls)
		usage: usage(input_tokens, output_tokens)
	}
}

pub fn (adapter &AnthropicCompatible) generate_stream(request Request, on_delta DeltaHandler) !Response {
	if adapter.api_key == '' {
		return praxo_error('MODEL_CONFIG', 'anthropic: API key is required')
	}
	if adapter.model == '' {
		return praxo_error('MODEL_CONFIG', 'anthropic: model is required')
	}
	mut payload := anthropic_payload(adapter, request)
	payload['stream'] = json2.Any(true)
	text := adapter.stream_transport(adapter.base_url, adapter.api_key, adapter.version, '/v1/messages', payload)!
	return anthropic_parse_sse(text, on_delta)
}