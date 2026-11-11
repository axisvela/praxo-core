module praxo

import x.json2

@[heap]
pub struct AnthropicCompatible {
pub mut:
	base_url   string
	model      string
	api_key    string
	version    string = '2023-06-01'
	max_tokens int = 1024
	transport  ProviderTransport = provider_default_transport
}

pub struct AnthropicOptions {
pub:
	api_key    string
	version    string
	max_tokens int
	transport  ProviderTransport = provider_default_transport
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
	}
}

pub fn anthropic_compatible_model(adapter &AnthropicCompatible) &Model {
	return callback_model(fn [adapter] (request Request) !Response {
		return adapter.generate(request)
	})
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
