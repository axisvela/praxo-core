module praxo

import x.json2

@[heap]
pub struct GeminiCompatible {
pub mut:
	base_url          string
	model             string
	api_key           string
	max_output_tokens int
	transport         ProviderTransport = provider_default_transport
}

pub struct GeminiOptions {
pub:
	api_key           string
	max_output_tokens int
	transport         ProviderTransport = provider_default_transport
}

pub fn gemini_compatible(base_url string, model string) &GeminiCompatible {
	return gemini_compatible_with_options(base_url, model, GeminiOptions{})
}

pub fn gemini_compatible_with_options(base_url string, model string, options GeminiOptions) &GeminiCompatible {
	return &GeminiCompatible{
		base_url: base_url.trim_right('/')
		model: model
		api_key: options.api_key
		max_output_tokens: options.max_output_tokens
		transport: options.transport
	}
}

pub fn gemini_compatible_model(adapter &GeminiCompatible) &Model {
	return callback_model(fn [adapter] (request Request) !Response {
		return adapter.generate(request)
	})
}

fn gemini_text_part(text string) json2.Any {
	mut part := map[string]json2.Any{}
	part['text'] = json2.Any(text)
	return json2.Any(part)
}

fn gemini_parts(message Message) []json2.Any {
	mut parts := []json2.Any{}
	if message.content != '' {
		parts << gemini_text_part(message.content)
	}
	for block in message.content_blocks {
		if block.kind == 'text' && block.text != '' {
			parts << gemini_text_part(block.text)
		}
	}
	for call in message.tool_calls {
		mut call_value := map[string]json2.Any{}
		call_value['name'] = json2.Any(call.name)
		call_value['args'] = json2.Any(call.arguments)
		mut part := map[string]json2.Any{}
		part['functionCall'] = json2.Any(call_value)
		parts << json2.Any(part)
	}
	return parts
}

fn gemini_flush(mut contents []json2.Any, mut parts []json2.Any) {
	if parts.len == 0 {
		return
	}
	mut content := map[string]json2.Any{}
	content['role'] = json2.Any('user')
	content['parts'] = json2.Any(parts)
	contents << json2.Any(content)
	parts.clear()
}

fn gemini_payload(adapter &GeminiCompatible, request Request) map[string]json2.Any {
	mut system_parts := []json2.Any{}
	mut contents := []json2.Any{}
	mut tool_parts := []json2.Any{}
	mut names := map[string]string{}
	for message in request.messages {
		if message.role == role_system {
			if message.content != '' {
				system_parts << gemini_text_part(message.content)
			}
			continue
		}
		if message.role == role_tool {
			name := names[message.tool_id] or { message.tool_id }
			mut response_value := map[string]json2.Any{}
			response_value['result'] = json2.Any(message.content)
			mut function_response := map[string]json2.Any{}
			function_response['name'] = json2.Any(if name != '' { name } else { 'tool' })
			function_response['response'] = json2.Any(response_value)
			mut tool_part := map[string]json2.Any{}
			tool_part['functionResponse'] = json2.Any(function_response)
			tool_parts << json2.Any(tool_part)
			continue
		}
		gemini_flush(mut contents, mut tool_parts)
		parts := gemini_parts(message)
		if parts.len > 0 {
			role := if message.role == role_assistant { 'model' } else { 'user' }
			mut content := map[string]json2.Any{}
			content['role'] = json2.Any(role)
			content['parts'] = json2.Any(parts)
			contents << json2.Any(content)
		}
		for call in message.tool_calls {
			if call.id != '' && call.name != '' {
				names[call.id] = call.name
			}
		}
	}
	gemini_flush(mut contents, mut tool_parts)
	mut payload := map[string]json2.Any{}
	payload['contents'] = json2.Any(contents)
	if system_parts.len > 0 {
		mut system_instruction := map[string]json2.Any{}
		system_instruction['parts'] = json2.Any(system_parts)
		payload['system_instruction'] = json2.Any(system_instruction)
	}
	if request.tools.len > 0 {
		mut declarations := []json2.Any{cap: request.tools.len}
		for tool in request.tools {
			mut parameters := map[string]json2.Any{}
			parameters['type'] = json2.Any('object')
			mut properties := map[string]json2.Any{}
			parameters['properties'] = json2.Any(properties)
			mut declaration := map[string]json2.Any{}
			declaration['name'] = json2.Any(tool.name)
			declaration['description'] = json2.Any(tool.description)
			declaration['parameters'] = json2.Any(parameters)
			declarations << json2.Any(declaration)
		}
		mut tool_group := map[string]json2.Any{}
		tool_group['functionDeclarations'] = json2.Any(declarations)
		payload['tools'] = json2.Any([json2.Any(tool_group)])
		mut calling_config := map[string]json2.Any{}
		calling_config['mode'] = json2.Any(gemini_mode(request.tool_choice))
		mut tool_config := map[string]json2.Any{}
		tool_config['functionCallingConfig'] = json2.Any(calling_config)
		payload['toolConfig'] = json2.Any(tool_config)
	}
	if adapter.max_output_tokens > 0 {
		mut generation_config := map[string]json2.Any{}
		generation_config['maxOutputTokens'] = json2.Any(f64(adapter.max_output_tokens))
		payload['generationConfig'] = json2.Any(generation_config)
	}
	return payload
}

fn gemini_mode(choice string) string {
	if choice == 'required' {
		return 'ANY'
	}
	if choice == 'none' {
		return 'NONE'
	}
	return 'AUTO'
}

fn gemini_urlencode(value string) string {
	mut out := ''
	for index in 0 .. value.len {
		character := value[index]
		if (character >= `a` && character <= `z`) || (character >= `A` && character <= `Z`) ||
			(character >= `0` && character <= `9`) || character == `-` || character == `_` ||
			character == `.` || character == `~` {
			out += character.ascii_str()
		} else {
			out += '%' + character.hex()
		}
	}
	return out
}

fn gemini_parse_response(data map[string]json2.Any) !Response {
	candidates := get_array(data, 'candidates')
	mut candidate := map[string]json2.Any{}
	if candidates.len > 0 {
		candidate = as_object(candidates[0])
	}
	mut text := ''
	mut calls := []ToolCall{}
	for item in get_array(get_object(candidate, 'content'), 'parts') {
		part := as_object(item)
		text += get_string(part, 'text') or { '' }
		call_value := get_object(part, 'functionCall')
		if call_value.len > 0 {
			calls << tool_call(
				'call-${calls.len + 1}',
				get_string(call_value, 'name') or { '' },
				as_object(get(call_value, 'args') or { json2.null })
			)
		}
	}
	usage_value := get_object(data, 'usageMetadata')
	return response(message_assistant(text, calls), usage(
		get_int(usage_value, 'promptTokenCount', 0),
		get_int(usage_value, 'candidatesTokenCount', 0)
	))
}

pub fn (adapter &GeminiCompatible) generate(request Request) !Response {
	if adapter.api_key == '' {
		return praxo_error('MODEL_CONFIG', 'gemini: API key is required')
	}
	if adapter.model == '' {
		return praxo_error('MODEL_CONFIG', 'gemini: model is required')
	}
	payload := gemini_payload(adapter, request)
	path := '/v1beta/models/${gemini_urlencode(adapter.model)}:generateContent'
	mut headers := map[string]string{}
	headers['x-goog-api-key'] = adapter.api_key
	data := adapter.transport(adapter.base_url, path, payload, headers)!
	return gemini_parse_response(data)
}
