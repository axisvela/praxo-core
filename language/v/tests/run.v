module main

import praxo
import x.json2

fn otel_long_body() string {
	mut body := ''
	for _ in 0 .. 600 {
		body += 'x'
	}
	return body
}

fn test_json() {
	value := praxo.parse_json('{"name":"echo","input":{"text":"hi"}}') or { panic(err) }
	assert praxo.get_string(value, 'name') or { '' } == 'echo'
	other := praxo.parse_json('{"input":{"text":"hi"},"name":"echo"}') or { panic(err) }
	assert praxo.json_equals(value, other)
	encoded := praxo.encode_json(value)
	roundtrip := praxo.parse_json(encoded) or { panic(err) }
	assert praxo.json_equals(value, roundtrip)
}

fn test_toolcall() {
	call := praxo.parse_tool_call('{"name":"echo","input":{"text":"hi"}}') or {
		panic('json call missing')
	}
	assert call.name == 'echo'
	assert praxo.parse_tool_call('plain text') == none
	xml := praxo.parse_tool_call('<tool_call name="echo">{"text":"hi"}</tool_call>') or {
		panic('xml call missing')
	}
	assert xml.name == 'echo'
	tag := praxo.parse_tool_call('<echo.echo>{"text":"hi"}</echo.echo>') or {
		panic('tag call missing')
	}
	assert tag.name == 'echo.echo'
	plain := praxo.parse_tool_call('echo.run {"text":"hi"}') or { panic('plain call missing') }
	assert plain.name == 'echo.run'
	stripped := praxo.strip_tool_call_markup('hello<tool_call name="echo">{"text":"hi"}</tool_call>world')
	assert stripped == 'helloworld'
}

fn test_jsonschema() {
	schema := praxo.parse_json('{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}') or {
		panic(err)
	}
	valid := praxo.parse_json('{"name":"ok"}') or { panic(err) }
	assert praxo.validate_schema(schema, valid).len == 0
	empty := praxo.parse_json('{}') or { panic(err) }
	errors := praxo.validate_schema(schema, empty)
	assert errors.len == 1
	assert errors[0].path == '$.name'
	pattern := praxo.parse_json('{"type":"string","pattern":"^a+$"}') or { panic(err) }
	assert praxo.validate_schema(pattern, json2.Any('aaa')).len == 0
	assert praxo.validate_schema(pattern, json2.Any('b')).len == 1
	array_schema := praxo.parse_json('{"type":"array","items":{"type":"object","properties":{"values":{"type":"array","items":{"type":"integer"}}},"required":["values"]}}') or { panic(err) }
	invalid := praxo.parse_json('[{"values":[1,"bad"]},{}]') or { panic(err) }
	array_errors := praxo.validate_schema(array_schema, invalid)
	assert array_errors.len == 2
	assert array_errors[0].path == '$[0].values[1]'
	assert array_errors[1].path == '$[1].values'
}

fn test_plugin() {
	raw := '{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},"protocol":"jsonrpc-2","capabilities":["echo"],"permissions":{},"limits":{},"health":{},"isolation":"process"}'
	manifest := praxo.parse_manifest(raw) or { panic(err) }
	assert manifest.id == 'com.example.echo'
	mut invalid := false
	praxo.parse_manifest(raw + '{}') or {
		invalid = true
		praxo.Manifest{}
	}
	assert invalid
}

fn test_memory() {
	mut store := praxo.memory_store()
	store.put('s1', praxo.memory_record('m1', 'event', 'Alpha', '2026-01-01T00:00:00Z'))
	store.put('s1', praxo.memory_record('m2', 'event', 'beta', '2026-01-02T00:00:00Z'))
	store.put('s1', praxo.memory_record('m3', 'decision', 'ALPHABET', '2026-01-03T00:00:00Z'))
	records := store.search('s1', 'alpha', 10)
	assert records.len == 2
	assert records[0].id == 'm3'
	assert records[1].id == 'm1'
	assert store.search('s1', 'alpha', 1)[0].id == 'm3'
	assert store.search('s2', 'alpha', 10).len == 0
}

fn test_checkpoint() {
	mut allow := praxo.checkpoint_allowlist()
	allow.register('spec.payload') or { panic(err) }
	value := praxo.parse_json('{"value":"x"}') or { panic(err) }
	data := allow.marshal('spec.payload', value) or { panic(err) }
	decoded := allow.unmarshal(data) or { panic(err) }
	assert praxo.json_equals(decoded, value)
	mut code := ''
	allow.marshal('spec.missing', json2.null) or {
		code = praxo.error_code(err)
		''
	}
	assert code == 'CHECKPOINT_TYPE_NOT_ALLOWED'
}

fn test_path_normalization() {
	assert praxo.normalize_path('../allowed/secret') == '../allowed/secret'
	assert praxo.normalize_path('../../allowed/secret') == '../../allowed/secret'
	assert praxo.normalize_path('../dir/../../allowed/secret') == '../../allowed/secret'
	assert praxo.normalize_path('dir/../allowed/secret') == 'allowed/secret'
	assert praxo.normalize_path('/../../allowed/secret') == '/allowed/secret'
	checker := praxo.path_checker([praxo.PathGrant{root: 'allowed', access: 'read'}]) or {
		panic(err)
	}
	assert !praxo.path_allowed(checker, '../allowed/secret', 'read')
	assert !praxo.path_allowed(checker, '../../allowed/secret', 'read')
	assert !praxo.path_allowed(checker, '../dir/../../allowed/secret', 'read')
	assert praxo.path_allowed(checker, 'dir/../allowed/secret', 'read')
}

fn test_context() {
	messages := [
		praxo.message('system', 'sys'),
		praxo.message('user', 'message 0'),
		praxo.message('user', 'message 1'),
	]
	assert praxo.estimate_tokens(messages) == 16
	output, ok := praxo.compact_context(praxo.context_budget(0, 0), messages)
	assert ok
	assert output.len == 3
}

fn test_pii() {
	assert praxo.pii_redact('email a@b.com') == 'email [REDACTED:email]'
	assert praxo.pii_redact('ssn 123-45-6789') == 'ssn [REDACTED:ssn]'
	assert praxo.pii_redact('Contact a@b.com. Then a@b.com, a@b.com! (a@b.com).') == 'Contact [REDACTED:email]. Then [REDACTED:email], [REDACTED:email]! ([REDACTED:email]).'
	assert praxo.pii_redact('a@b.com...') == '[REDACTED:email]...'
	assert praxo.pii_redact('call 415-555-2671') == 'call [REDACTED:phone]'
	assert praxo.pii_redact('call +1 (415) 555-2671.') == 'call [REDACTED:phone].'
	assert praxo.pii_redact('version 1.2.3') == 'version 1.2.3'
}

fn test_agent() {
	model := praxo.scripted_model([
		praxo.response(praxo.message_assistant('hello', []praxo.ToolCall{}), praxo.usage(0, 0)),
	])
	sink := &praxo.Sink{}
	mut options := praxo.agent_options(model)
	options.events = sink
	result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'hello') or {
		panic(err)
	}
	assert result.output == 'hello'
	assert result.steps == 1
	assert sink.kinds == ['run.started', 'run.completed']
}

fn test_run_ids() {
	model := praxo.static_model('ok')
	first := praxo.run_agent(praxo.agent_options(model), praxo.session('s1', []praxo.Message{}), 'hi') or { panic(err) }
	second := praxo.run_agent(praxo.agent_options(model), praxo.session('s1', []praxo.Message{}), 'hi') or { panic(err) }
	assert first.run_id != second.run_id
}

fn test_agent_tool() {
	model := praxo.scripted_model([
		praxo.response(praxo.message_assistant('', [
			praxo.tool_call('c1', 'echo', {'text': json2.Any('hi')}),
		]), praxo.usage(0, 0)),
		praxo.response(praxo.message_assistant('done', []praxo.ToolCall{}), praxo.usage(0, 0)),
	])
	tool := praxo.func_tool('echo', 'Echo')
	sink := &praxo.Sink{}
	mut options := praxo.agent_options(model)
	options.tools = [tool]
	options.events = sink
	result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'use') or {
		panic(err)
	}
	assert result.output == 'done'
	assert tool.calls == 1
	assert sink.kinds == ['run.started', 'tool.call', 'run.completed']
}

fn consumer_model(req praxo.Request) !praxo.Response {
	assert req.tools.len == 1
	assert req.tools[0].name == 'echo'
	assert req.messages[0].content == 'use'
	if req.messages.len == 1 {
		return praxo.response(praxo.message_assistant('', [
			praxo.tool_call('c1', 'echo', {'text': json2.Any('hi')}),
		]), praxo.usage(2, 3))
	}
	assert req.messages.len == 3
	assert req.messages[1].tool_calls[0].id == 'c1'
	assert req.messages[2].role == praxo.role_tool
	assert req.messages[2].tool_id == 'c1'
	value := praxo.parse_json(req.messages[2].content)!
	assert praxo.get_string(value, 'text') or { '' } == 'hi'
	return praxo.response(praxo.message_assistant('custom done', []praxo.ToolCall{}), praxo.usage(4, 5))
}

fn consumer_failure(_req praxo.Request) !praxo.Response {
	return praxo.praxo_error('MODEL_ERROR', 'consumer failed')
}

fn selection_model(req praxo.Request) !praxo.Response {
	assert req.tools.len == 1
	assert req.tools[0].name == 'echo'
	if req.messages.len == 1 {
		return praxo.response(praxo.message_assistant('', [
			praxo.tool_call('c1', 'echo', {}),
		]), praxo.usage(0, 0))
	}
	return praxo.response(praxo.message_assistant('', [
		praxo.tool_call('c2', 'denied', {}),
	]), praxo.usage(0, 0))
}

fn empty_selection_model(req praxo.Request) !praxo.Response {
	assert req.tools.len == 0
	return praxo.response(praxo.message_assistant('', [
		praxo.tool_call('c1', 'echo', {}),
	]), praxo.usage(0, 0))
}

fn default_selection_model(req praxo.Request) !praxo.Response {
	assert req.tools.len == 2
	assert req.tools[0].name == 'echo'
	assert req.tools[1].name == 'denied'
	if req.messages.len == 1 {
		return praxo.response(praxo.message_assistant('', [
			praxo.tool_call('c1', 'denied', {}),
		]), praxo.usage(0, 0))
	}
	return praxo.response(praxo.message_assistant('done', []praxo.ToolCall{}), praxo.usage(0, 0))
}

fn test_agent_tool_selection() {
	allowed := praxo.func_tool('echo', 'Echo')
	denied := praxo.func_tool('denied', 'Denied')
	sink := &praxo.Sink{}
	mut options := praxo.agent_options(praxo.callback_model(selection_model))
	options.tools = [allowed, denied]
	options.tool_selection = praxo.tool_selection(['echo'])
	options.events = sink
	mut code := ''
	praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'use') or {
		code = praxo.error_code(err)
		praxo.RunResult{}
	}
	assert code == 'AGENT_TOOL_NOT_SELECTED'
	assert allowed.calls == 1
	assert denied.calls == 0
	assert sink.kinds == ['run.started', 'tool.call', 'run.failed']

	mut empty_options := praxo.agent_options(praxo.callback_model(empty_selection_model))
	empty_options.tools = [allowed]
	empty_options.tool_selection = praxo.tool_selection([]string{})
	code = ''
	praxo.run_agent(empty_options, praxo.session('s1', []praxo.Message{}), 'use') or {
		code = praxo.error_code(err)
		praxo.RunResult{}
	}
	assert code == 'AGENT_TOOL_NOT_SELECTED'
	assert allowed.calls == 1

	mut default_options := praxo.agent_options(praxo.callback_model(default_selection_model))
	default_options.tools = [allowed, denied]
	result := praxo.run_agent(default_options, praxo.session('s1', []praxo.Message{}), 'use') or {
		panic(err)
	}
	assert result.output == 'done'
	assert denied.calls == 1
}

fn test_callback_model() {
	tool := praxo.func_tool('echo', 'Echo')
	sink := &praxo.Sink{}
	mut options := praxo.agent_options(praxo.callback_model(consumer_model))
	options.tools = [tool]
	options.events = sink
	result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'use') or { panic(err) }
	assert result.output == 'custom done'
	assert result.steps == 2
	assert result.usage.input_tokens == 6
	assert result.usage.output_tokens == 8
	assert tool.calls == 1
	assert sink.kinds == ['run.started', 'tool.call', 'run.completed']

	failure_sink := &praxo.Sink{}
	mut failure_options := praxo.agent_options(praxo.callback_model(consumer_failure))
	failure_options.events = failure_sink
	mut failed := false
	praxo.run_agent(failure_options, praxo.session('s1', []praxo.Message{}), 'use') or {
		failed = true
		assert praxo.error_code(err) == 'MODEL_ERROR'
		assert err.msg().contains('consumer failed')
		praxo.RunResult{}
	}
	assert failed
	assert failure_sink.kinds == ['run.started', 'run.failed']

	fallback := praxo.fallback_model(praxo.callback_model(consumer_failure), praxo.static_model('fallback'))
	fallback_result := praxo.run_agent(praxo.agent_options(fallback), praxo.session('s1', []praxo.Message{}), 'use') or { panic(err) }
	assert fallback_result.output == 'fallback'
}

fn privacy_model(req praxo.Request) !praxo.Response {
	assert req.messages[0].content == 'system [REDACTED:email]'
	assert req.messages[1].content == 'history [REDACTED:ssn]'
	assert req.messages[1].content_blocks[0].text == '[REDACTED:email]'
	assert req.messages[2].content == 'prompt [REDACTED:email].'
	if req.messages.len == 3 {
		return praxo.response(praxo.message_assistant('assistant a@b.com', [
			praxo.tool_call('c1', 'echo', {'nested': json2.Any([json2.Any('Contact a@b.com.')])}),
		]), praxo.usage(0, 0))
	}
	assert req.messages[3].content == 'assistant [REDACTED:email]'
	assert !(req.messages[3].tool_calls[0].arguments['nested'] or { json2.null }).str().contains('a@b.com')
	assert (req.messages[3].tool_calls[0].arguments['nested'] or { json2.null }).str().contains('[REDACTED:email]')
	value := praxo.parse_json(req.messages[4].content)!
	assert praxo.encode_json(value).contains('Contact [REDACTED:email].')
	assert !praxo.encode_json(value).contains('a@b.com')
	return praxo.response(praxo.message_assistant('final a@b.com', []praxo.ToolCall{}), praxo.usage(0, 0))
}

fn plain_privacy_model(req praxo.Request) !praxo.Response {
	assert req.messages[0].content == 'a@b.com'
	return praxo.response(praxo.message_assistant('ok', []praxo.ToolCall{}), praxo.usage(0, 0))
}

fn repair_output(_text string) string {
	return '{"name":"repaired"}'
}

fn test_agent_middleware() {
	history := praxo.Message{role: praxo.role_user, content: 'history 123-45-6789', content_blocks: [praxo.content_block('text', 'a@b.com')]}
	session := praxo.session('s1', [history])
	tool := praxo.func_tool('echo', 'Echo')
	mut options := praxo.agent_options(praxo.callback_model(privacy_model))
	options.system_prompt = 'system a@b.com'
	options.pii_redaction = true
	options.tools = [tool]
	for _ in 0 .. 2 {
		result := praxo.run_agent(options, session, 'prompt a@b.com.') or { panic(err) }
		assert result.output == 'final a@b.com'
	}
	assert session.messages[0].content == 'history 123-45-6789'
	assert session.messages[0].content_blocks[0].text == 'a@b.com'
	praxo.run_agent(praxo.agent_options(praxo.callback_model(plain_privacy_model)), praxo.session('s1', []praxo.Message{}), 'a@b.com') or { panic(err) }

	schema := praxo.parse_json('{"type":"object","required":["name"]}') or { panic(err) }
	mut structured := praxo.agent_options(praxo.static_model('{"name":"valid"}'))
	structured.structured_output = praxo.structured_output(schema, 0, none)
	result := praxo.run_agent(structured, praxo.session('s1', []praxo.Message{}), '') or { panic(err) }
	assert result.output == '{"name":"valid"}'
	structured.model = praxo.static_model('invalid')
	sink := &praxo.Sink{}
	structured.events = sink
	mut code := ''
	praxo.run_agent(structured, praxo.session('s1', []praxo.Message{}), '') or {
		code = praxo.error_code(err)
		praxo.RunResult{}
	}
	assert code == 'AGENT_STRUCTURED_OUTPUT'
	assert sink.kinds == ['run.started', 'run.failed']
	structured.structured_output = praxo.structured_output(schema, 1, repair_output)
	repaired := praxo.run_agent(structured, praxo.session('s1', []praxo.Message{}), '') or { panic(err) }
	assert repaired.output == '{"name":"repaired"}'
	array_schema := praxo.parse_json('{"type":"array","items":{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}}') or { panic(err) }
	structured.structured_output = praxo.structured_output(array_schema, 0, none)
	structured.model = praxo.static_model('[{"name":"valid"}]')
	valid_array := praxo.run_agent(structured, praxo.session('s1', []praxo.Message{}), '') or { panic(err) }
	assert valid_array.output == '[{"name":"valid"}]'
	structured.model = praxo.static_model('[{"name":"valid"},{"name":42}]')
	code = ''
	praxo.run_agent(structured, praxo.session('s1', []praxo.Message{}), '') or {
		code = praxo.error_code(err)
		praxo.RunResult{}
	}
	assert code == 'AGENT_STRUCTURED_OUTPUT'
}

fn limit_model(req praxo.Request) !praxo.Response {
	if req.messages.len == 1 {
		return praxo.response(praxo.message_assistant('', [
			praxo.tool_call('c1', 'echo', {}),
			praxo.tool_call('c2', 'echo', {}),
		]), praxo.usage(0, 0))
	}
	return praxo.response(praxo.message_assistant('done', []praxo.ToolCall{}), praxo.usage(0, 0))
}

fn test_agent_call_limits() {
	tool := praxo.func_tool('echo', 'Echo')
	sink := &praxo.Sink{}
	mut options := praxo.agent_options(praxo.callback_model(limit_model))
	options.tools = [tool]
	options.events = sink
	options.tool_call_limit = 1
	for _ in 0 .. 2 {
		mut code := ''
		praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'use') or {
			code = praxo.error_code(err)
			praxo.RunResult{}
		}
		assert code == 'AGENT_TOOL_CALL_LIMIT'
	}
	assert tool.calls == 2
	assert sink.kinds == ['run.started', 'tool.call', 'run.failed', 'run.started', 'tool.call', 'run.failed']
	options.tool_call_limit = 0
	options.model_call_limit = 1
	model := praxo.scripted_model([
		praxo.response(praxo.message_assistant('', [praxo.tool_call('c1', 'echo', {})]), praxo.usage(0, 0)),
		praxo.response(praxo.message_assistant('done', []praxo.ToolCall{}), praxo.usage(0, 0)),
	])
	options.model = model
	mut code := ''
	praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'use') or {
		code = praxo.error_code(err)
		praxo.RunResult{}
	}
	assert code == 'AGENT_MODEL_CALL_LIMIT'
	assert model.index == 1
	result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'use') or { panic(err) }
	assert result.output == 'done'
	options.model = praxo.callback_model(limit_model)
	options.model_call_limit = 0
	result2 := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'use') or { panic(err) }
	assert result2.output == 'done'
}

fn test_openai_compatible() {
	transport := fn (_base_url string, _api_key string, path string, payload map[string]json2.Any) !map[string]json2.Any {
		assert path == '/chat/completions'
		assert praxo.get_string(payload, 'model') or { '' } == 'test-model'
		assert praxo.get_string(payload, 'tool_choice') or { '' } == 'auto'
		messages := praxo.get_array(payload, 'messages')
		assert messages.len == 4
		assistant := praxo.as_object(messages[2])
		calls := praxo.get_array(assistant, 'tool_calls')
		assert calls.len == 1
		function_value := praxo.get_object(calls[0], 'function')
		assert praxo.get_string(function_value, 'name') or { '' } == 'echo'
		arguments_text := praxo.get_string(function_value, 'arguments') or { '' }
		arguments := praxo.parse_json(arguments_text) or { panic(err) }
		assert praxo.get_string(arguments, 'text') or { '' } == 'hi'
		tool_message := praxo.as_object(messages[3])
		assert praxo.get_string(tool_message, 'tool_call_id') or { '' } == 'call-1'
		tools := praxo.get_array(payload, 'tools')
		assert tools.len == 1
		tool_function := praxo.get_object(praxo.as_object(tools[0]), 'function')
		assert praxo.get_string(tool_function, 'name') or { '' } == 'echo'
		parameters := praxo.get_object(tool_function, 'parameters')
		assert praxo.get_string(parameters, 'type') or { '' } == 'object'
		data := praxo.parse_json('{"choices":[{"message":{"role":"assistant","content":"hello","tool_calls":[{"id":"call-1","type":"function","function":{"name":"echo","arguments":"{\\"text\\":\\"hi\\"}"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":7,"completion_tokens":3}}') or { panic(err) }
		return praxo.as_object(data)
	}
	adapter := praxo.openai_compatible_with_options('https://example.test/v1/', 'test-model', praxo.OpenAIOptions{
		api_key: 'secret'
		transport: transport
	})
	request := praxo.Request{
		messages: [
			praxo.message(praxo.role_system, 'sys'),
			praxo.message(praxo.role_user, 'hi'),
			praxo.message_assistant('', [
				praxo.tool_call('call-1', 'echo', {'text': json2.Any('hi')}),
			]),
			praxo.message_tool('{"ok":true}', 'call-1'),
		]
		tools: [praxo.ToolSpec{name: 'echo', description: 'Echo'}]
		tool_choice: 'auto'
	}
	result := adapter.generate(request) or { panic(err) }
	assert result.message.content == 'hello'
	assert result.message.tool_calls.len == 1
	assert result.message.tool_calls[0].id == 'call-1'
	assert result.message.tool_calls[0].name == 'echo'
	text := result.message.tool_calls[0].arguments['text'] or { json2.Any('') }
	assert praxo.as_string(text) or { '' } == 'hi'
	assert result.usage.input_tokens == 7
	assert result.usage.output_tokens == 3

	mut model := praxo.openai_compatible_model(adapter)
	wrapped := model.generate(request) or { panic(err) }
	assert wrapped.message.content == 'hello'

	stream_transport := fn (_base_url string, _api_key string, path string, payload map[string]json2.Any) !string {
		assert path == '/chat/completions'
		assert praxo.get_bool(payload, 'stream', false)
		return [
			r'data: {"choices":[{"delta":{"content":"he"}}]}',
			r'data: {"choices":[{"delta":{"content":"llo"}}]}',
			r'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call-1","function":{"name":"ec","arguments":"{\"text\":"}}]}}]}',
			r'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"ho","arguments":"\"hi\"}"}}]}}],"usage":{"prompt_tokens":4,"completion_tokens":2}}',
			r'data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}',
			'data: [DONE]',
		].join('\n\n') + '\n\n'
	}
	stream_adapter := praxo.openai_compatible_with_options('https://example.test/v1', 'test-model', praxo.OpenAIOptions{
		stream_transport: stream_transport
	})
	mut streaming_model := praxo.openai_compatible_model(stream_adapter)
	mut options := praxo.agent_options(streaming_model)
	options.streaming = true
	options.on_delta = fn (delta string) {}
	stream_result := streaming_model.generate_stream(request, options.on_delta) or { panic(err) }
	assert stream_result.message.content == 'hello'
	assert stream_result.message.tool_calls.len == 1
	assert stream_result.message.tool_calls[0].id == 'call-1'
	assert stream_result.message.tool_calls[0].name == 'echo'
	stream_text := stream_result.message.tool_calls[0].arguments['text'] or { json2.Any('') }
	assert praxo.as_string(stream_text) or { '' } == 'hi'
	assert stream_result.usage.input_tokens == 4
	assert stream_result.usage.output_tokens == 2

	agent_stream_transport := fn (_base_url string, _api_key string, _path string, _payload map[string]json2.Any) !string {
		return [
			r'data: {"choices":[{"delta":{"content":"ok"}}]}',
			r'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}',
			'data: [DONE]',
		].join('\n\n') + '\n\n'
	}
	agent_stream_adapter := praxo.openai_compatible_with_options('https://example.test/v1', 'm', praxo.OpenAIOptions{
		stream_transport: agent_stream_transport
	})
	mut agent_stream_model := praxo.openai_compatible_model(agent_stream_adapter)
	mut agent_stream_options := praxo.agent_options(agent_stream_model)
	agent_stream_options.streaming = true
	agent_stream_options.on_delta = fn (delta string) {}
	agent_stream_result := praxo.run_agent(agent_stream_options, praxo.session('s1', []praxo.Message{}), 'go') or { panic(err) }
	assert agent_stream_result.output == 'ok'

	invalid := fn (_base_url string, _api_key string, _path string, _payload map[string]json2.Any) !map[string]json2.Any {
		data := praxo.parse_json('{"choices":[{"message":{"content":"","tool_calls":[{"id":"call-1","function":{"name":"echo","arguments":"not json"}}]}}]}') or { panic(err) }
		return praxo.as_object(data)
	}
	invalid_adapter := praxo.openai_compatible_with_options('https://example.test/v1', 'm', praxo.OpenAIOptions{
		transport: invalid
	})
	mut invalid_code := ''
	invalid_adapter.generate(request) or {
		invalid_code = praxo.error_code(err)
		praxo.Response{}
	}
	assert invalid_code == 'PROVIDER_JSON'

	missing := praxo.openai_compatible('', 'm')
	mut missing_code := ''
	missing.generate(request) or {
		missing_code = praxo.error_code(err)
		praxo.Response{}
	}
	assert missing_code == 'PROVIDER_HTTP'

	http_transport := fn (_base_url string, _api_key string, _path string, _payload map[string]json2.Any) !map[string]json2.Any {
		return praxo.praxo_error('PROVIDER_HTTP', 'provider returned HTTP 500')
	}
	http_adapter := praxo.openai_compatible_with_options('https://example.test/v1', 'm', praxo.OpenAIOptions{
		transport: http_transport
	})
	mut http_code := ''
	http_adapter.generate(request) or {
		http_code = praxo.error_code(err)
		praxo.Response{}
	}
	assert http_code == 'PROVIDER_HTTP'
}

fn test_anthropic_compatible() {
	transport := fn (_base_url string, path string, payload map[string]json2.Any, headers map[string]string) !map[string]json2.Any {
		assert path == '/v1/messages'
		assert (headers['x-api-key'] or { '' }) == 'secret'
		assert (headers['anthropic-version'] or { '' }) == '2023-06-01'
		assert praxo.get_string(payload, 'model') or { '' } == 'test-model'
		assert praxo.get_string(payload, 'system') or { '' } == 'sys'
		assert praxo.get_int(payload, 'max_tokens', 0) == 1024
		messages := praxo.get_array(payload, 'messages')
		assert messages.len == 3
		assistant := praxo.as_object(messages[1])
		assert praxo.get_string(assistant, 'role') or { '' } == 'assistant'
		assistant_content := praxo.as_array(praxo.get(assistant, 'content') or { json2.null })
		assert praxo.get_string(praxo.as_object(assistant_content[0]), 'type') or { '' } == 'tool_use'
		tool_message := praxo.as_object(messages[2])
		assert praxo.get_string(tool_message, 'role') or { '' } == 'user'
		result_content := praxo.as_array(praxo.get(tool_message, 'content') or { json2.null })
		assert praxo.get_string(praxo.as_object(result_content[0]), 'tool_use_id') or { '' } == 'call-1'
		tools := praxo.get_array(payload, 'tools')
		assert tools.len == 1
		assert praxo.get_string(praxo.as_object(tools[0]), 'name') or { '' } == 'echo'
		data := praxo.parse_json('{"content":[{"type":"text","text":"hello"},{"type":"tool_use","id":"tool-1","name":"echo","input":{"text":"hi"}}],"usage":{"input_tokens":5,"output_tokens":6}}') or { panic(err) }
		return praxo.as_object(data)
	}
	adapter := praxo.anthropic_compatible_with_options('https://api.anthropic.com/', 'test-model', praxo.AnthropicOptions{
		api_key: 'secret'
		transport: transport
	})
	request := praxo.Request{
		messages: [
			praxo.message(praxo.role_system, 'sys'),
			praxo.message(praxo.role_user, 'hi'),
			praxo.message_assistant('', [
				praxo.tool_call('call-1', 'echo', {'text': json2.Any('hi')}),
			]),
			praxo.message_tool('{"ok":true}', 'call-1'),
		]
		tools: [praxo.tool_spec('echo', 'Echo')]
		tool_choice: 'auto'
	}
	result := adapter.generate(request) or { panic(err) }
	assert result.message.content == 'hello'
	assert result.message.tool_calls.len == 1
	assert result.message.tool_calls[0].id == 'tool-1'
	assert result.message.tool_calls[0].name == 'echo'
	assert result.usage.input_tokens == 5
	assert result.usage.output_tokens == 6

	mut model := praxo.anthropic_compatible_model(adapter)
	wrapped := model.generate(request) or { panic(err) }
	assert wrapped.message.content == 'hello'

	missing := praxo.anthropic_compatible('https://api.anthropic.com', 'test-model')
	mut missing_code := ''
	missing.generate(request) or {
		missing_code = praxo.error_code(err)
		praxo.Response{}
	}
	assert missing_code == 'MODEL_CONFIG'
}

fn test_gemini_compatible() {
	transport := fn (_base_url string, path string, payload map[string]json2.Any, headers map[string]string) !map[string]json2.Any {
		assert path == '/v1beta/models/test-model:generateContent'
		assert (headers['x-goog-api-key'] or { '' }) == 'secret'
		contents := praxo.get_array(payload, 'contents')
		assert contents.len == 3
		assistant := praxo.as_object(contents[1])
		assert praxo.get_string(assistant, 'role') or { '' } == 'model'
		parts := praxo.get_array(assistant, 'parts')
		assert praxo.get_string(praxo.get_object(parts[0], 'functionCall'), 'name') or { '' } == 'echo'
		tool_message := praxo.as_object(contents[2])
		assert praxo.get_string(tool_message, 'role') or { '' } == 'user'
		tool_parts := praxo.get_array(tool_message, 'parts')
		assert praxo.get_string(praxo.get_object(tool_parts[0], 'functionResponse'), 'name') or { '' } == 'echo'
		system := praxo.get_object(payload, 'system_instruction')
		assert praxo.get_array(system, 'parts').len == 1
		tools := praxo.get_array(payload, 'tools')
		assert tools.len == 1
		declarations := praxo.get_array(praxo.as_object(tools[0]), 'functionDeclarations')
		assert declarations.len == 1
		data := praxo.parse_json('{"candidates":[{"content":{"parts":[{"text":"hello"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]}}],"usageMetadata":{"promptTokenCount":5,"candidatesTokenCount":6}}') or { panic(err) }
		return praxo.as_object(data)
	}
	adapter := praxo.gemini_compatible_with_options('https://generativelanguage.googleapis.com/', 'test-model', praxo.GeminiOptions{
		api_key: 'secret'
		transport: transport
	})
	request := praxo.Request{
		messages: [
			praxo.message(praxo.role_system, 'sys'),
			praxo.message(praxo.role_user, 'hi'),
			praxo.message_assistant('', [
				praxo.tool_call('call-1', 'echo', {'text': json2.Any('hi')}),
			]),
			praxo.message_tool('{"ok":true}', 'call-1'),
		]
		tools: [praxo.tool_spec('echo', 'Echo')]
		tool_choice: 'auto'
	}
	result := adapter.generate(request) or { panic(err) }
	assert result.message.content == 'hello'
	assert result.message.tool_calls.len == 1
	assert result.message.tool_calls[0].id == 'call-1'
	assert result.message.tool_calls[0].name == 'echo'
	assert result.usage.input_tokens == 5
	assert result.usage.output_tokens == 6

	mut model := praxo.gemini_compatible_model(adapter)
	wrapped := model.generate(request) or { panic(err) }
	assert wrapped.message.content == 'hello'

	stream_events := [
		'data: {"candidates":[{"content":{"parts":[{"text":"he"}]}}]}',
		'data: {"candidates":[{"content":{"parts":[{"text":"llo"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":4,"candidatesTokenCount":2}}',
	]
	stream_text := stream_events.join('\n\n')
	stream_transport := fn [stream_text] (_base_url string, _api_key string, path string, _payload map[string]json2.Any) !string {
		assert path.contains(':streamGenerateContent')
		assert path.contains('alt=sse')
		return stream_text
	}
	stream_adapter := praxo.gemini_compatible_with_options('https://generativelanguage.googleapis.com', 'test-model', praxo.GeminiOptions{
		api_key: 'secret'
		stream_transport: stream_transport
	})
	mut deltas := []string{}
	stream_result := stream_adapter.generate_stream(request, fn [mut deltas] (delta string) {
		deltas << delta
	}) or { panic(err) }
	assert deltas == ['he', 'llo']
	assert stream_result.message.content == 'hello'
	assert stream_result.message.tool_calls[0].name == 'echo'
	assert praxo.get_string(stream_result.message.tool_calls[0].arguments, 'text') or { '' } == 'hi'
	assert stream_result.usage.input_tokens == 4
	assert stream_result.usage.output_tokens == 2

	missing := praxo.gemini_compatible('https://generativelanguage.googleapis.com', 'test-model')
	mut missing_code := ''
	missing.generate(request) or {
		missing_code = praxo.error_code(err)
		praxo.Response{}
	}
	assert missing_code == 'MODEL_CONFIG'
}

fn test_harmovela() {
	transport := fn (_base_url string, path string, body string, headers map[string]string) !praxo.HarmovelaResponse {
		assert path == '/events'
		assert headers['content-type'] == 'application/json'
		envelope := praxo.parse_json(body) or { panic(err) }
		assert praxo.get_string(envelope, 'spec_version') or { '' } == '0.2'
		assert praxo.get_string(envelope, 'id') or { '' } == 'run-123-1700000000123456789'
		assert praxo.get_string(envelope, 'type') or { '' } == 'tool.call'
		assert praxo.get_string(envelope, 'source') or { '' } == 'praxo-core'
		assert praxo.get_string(envelope, 'created_at') or { '' } == '2023-11-14T22:13:20.123456789Z'
		payload := praxo.get_object(envelope, 'payload')
		assert praxo.get_string(payload, 'name') or { '' } == 'echo'
		assert praxo.get_string(payload, 'session_id') or { '' } == 's1'
		assert praxo.get_string(payload, 'run_id') or { '' } == 'run-123'
		return praxo.HarmovelaResponse{status: 204}
	}
	sink := praxo.new_harmovela_sink('http://127.0.0.1:8790/aep/api/', praxo.HarmovelaOptions{
		transport: transport
		clock: fn () i64 { return 1700000000123456789 }
	})
	event := praxo.Event{
		kind: 'tool.call'
		session_id: 's1'
		run_id: 'run-123'
		data: json2.Any({'name': json2.Any('echo')})
	}
	sink.emit(event) or { panic(err) }

	noop := fn (_base_url string, _path string, _body string, _headers map[string]string) !praxo.HarmovelaResponse {
		return praxo.HarmovelaResponse{status: 200}
	}
	mut wrapped := praxo.harmovela_sink('http://127.0.0.1:8790/aep/api', praxo.HarmovelaOptions{
		transport: noop
		clock: fn () i64 { return 1700000000000000000 }
	})
	wrapped.emit(praxo.Event{kind: 'run.started', session_id: 's1'})
	assert wrapped.last_error == ''

	failing := fn (_base_url string, _path string, _body string, _headers map[string]string) !praxo.HarmovelaResponse {
		return praxo.HarmovelaResponse{status: 500, body: 'boom'}
	}
	fail_sink := praxo.new_harmovela_sink('http://127.0.0.1:8790/aep/api', praxo.HarmovelaOptions{
		transport: failing
	})
	mut failure := ''
	fail_sink.emit(event) or {
		failure = err.msg()
	}
	assert failure.contains('HARMOVELA_HTTP')
	assert failure.contains('500')
	assert failure.contains('boom')

	missing_sink := praxo.new_harmovela_sink('', praxo.HarmovelaOptions{
		transport: noop
	})
	mut missing := ''
	missing_sink.emit(event) or {
		missing = praxo.error_code(err)
	}
	assert missing == 'HARMOVELA_URL'
}

fn test_otel_sink() {
	transport := fn (endpoint string, body string, headers map[string]string) !praxo.OtelResponse {
		assert endpoint == 'https://otel.test/v1/traces'
		assert (headers['content-type'] or { '' }) == 'application/json'
		envelope := praxo.parse_json(body) or { panic(err) }
			resource_spans := praxo.get_array(envelope, 'resourceSpans')
		assert resource_spans.len == 1
		scope_spans := praxo.get_array(praxo.as_object(resource_spans[0]), 'scopeSpans')
		assert scope_spans.len == 1
		spans := praxo.get_array(praxo.as_object(scope_spans[0]), 'spans')
		assert spans.len == 1
		span := praxo.as_object(spans[0])
		assert praxo.get_string(span, 'name') or { '' } == 'praxo.tool.call'
		trace_id := praxo.get_string(span, 'traceId') or { '' }
		span_id := praxo.get_string(span, 'spanId') or { '' }
		assert trace_id.len == 32
		assert span_id.len == 16
		assert praxo.get_string(span, 'startTimeUnixNano') or { '' } == '1794294000000000000'
		assert praxo.get_array(span, 'attributes').len > 0
		return praxo.OtelResponse{status: 200}
	}
	sink := praxo.new_otel_sink('https://otel.test/v1/traces', praxo.OtelOptions{
		allowed_data_keys: ['name']
		transport: transport
		clock: fn () i64 { return 1794294000000000000 }
	})
	event := praxo.Event{
		kind: 'tool.call'
		session_id: 's1'
		run_id: 'run-123'
		data: json2.Any({'name': json2.Any('echo'), 'secret': json2.Any('hidden')})
	}
	sink.emit(event) or { panic(err) }
	sink.emit(event) or { panic(err) }

	missing := praxo.new_otel_sink('', praxo.OtelOptions{ transport: transport })
	mut missing_code := ''
	missing.emit(event) or {
		missing_code = praxo.error_code(err)
	}
	assert missing_code == 'OTEL_URL'

	failing := fn (_endpoint string, _body string, _headers map[string]string) !praxo.OtelResponse {
		return praxo.OtelResponse{status: 503, body: 'unavailable'}
	}
	fail_sink := praxo.new_otel_sink('https://otel.test/v1/traces', praxo.OtelOptions{
		transport: failing
	})
	mut failure := ''
	fail_sink.emit(event) or {
		failure = err.msg()
	}
	assert failure.contains('OTEL_HTTP')
	assert failure.contains('503')
	assert failure.contains('unavailable')

	long_body := otel_long_body()
	long_failing := fn [long_body] (_endpoint string, _body string, _headers map[string]string) !praxo.OtelResponse {
		return praxo.OtelResponse{status: 500, body: long_body}
	}
	long_sink := praxo.new_otel_sink('https://otel.test/v1/traces', praxo.OtelOptions{
		transport: long_failing
	})
	mut long_failure := ''
	long_sink.emit(event) or {
		long_failure = err.msg()
	}
	assert long_failure.contains('OTEL_HTTP')
	assert long_failure.len < 600

	mut wrapped := praxo.otel_sink('https://otel.test/v1/traces', praxo.OtelOptions{
		transport: transport
		clock: fn () i64 { return 1794294000000000000 }
	})
	wrapped.emit(event)
	assert wrapped.last_error == ''
}

fn test_retriever() {
	retriever := praxo.func_retriever(fn (query string, limit int) ![]praxo.Document {
		return [praxo.document('doc-1', '${query}:${limit}')]
	})
	documents := praxo.retrieve_documents(retriever.retrieve, 'hello', 3) or { panic(err) }
	assert documents.len == 1
	assert documents[0].id == 'doc-1'
	assert documents[0].content == 'hello:3'
	second := retriever.retrieve_documents('hello', 2) or { panic(err) }
	assert second[0].content == 'hello:2'
	mut code := ''
	praxo.retrieve_documents(retriever.retrieve, 'hello', -1) or {
		code = praxo.error_code(err)
		[]praxo.Document{}
	}
	assert code == 'RETRIEVER_INVALID'
}

fn test_delegation() {
	runner := fn (request praxo.SubagentRequest) !praxo.SubagentResult {
		return praxo.subagent_result('task-1', request.agent_id, 'done')
	}
	mut manager := praxo.subagent_manager(runner)
	manager.clock = fn () i64 { return 1700000000123456789 }
	task := manager.run(praxo.subagent_request_mode('parent', 'child', 'look up', 'fork')) or {
		panic(err)
	}
	assert task.status == 'completed'
	assert task.mode == 'fork'
	assert task.output == 'done'
	assert task.error == ''
	assert task.created_at == '2023-11-14T22:13:20.123456789Z'
	direct := praxo.subagent_run(runner, praxo.subagent_request('parent', 'child', 'look up')) or {
		panic(err)
	}
	assert direct.status == 'completed'

	failing := fn (_request praxo.SubagentRequest) !praxo.SubagentResult {
		return praxo.praxo_error('BOOM', 'boom')
	}
	failing_manager := praxo.subagent_manager(failing)
	failed := failing_manager.run(praxo.subagent_request('parent', 'child', 'look up')) or {
		panic(err)
	}
	assert failed.status == 'failed'
	assert failed.error == 'BOOM'

	generic := fn (_request praxo.SubagentRequest) !praxo.SubagentResult {
		return error('bad')
	}
	generic_manager := praxo.subagent_manager(generic)
	generic_task := generic_manager.run(praxo.subagent_request('parent', 'child', 'look up')) or {
		panic(err)
	}
	assert generic_task.status == 'failed'
	assert generic_task.error == 'SUBAGENT_ERROR'

	mut code := ''
	manager.run(praxo.SubagentRequest{ parent_session_id: '', agent_id: 'child' }) or {
		code = praxo.error_code(err)
		praxo.SubagentTask{}
	}
	assert code == 'SUBAGENT_INVALID'
	code = ''
	manager.run(praxo.SubagentRequest{ parent_session_id: 'parent', agent_id: '' }) or {
		code = praxo.error_code(err)
		praxo.SubagentTask{}
	}
	assert code == 'SUBAGENT_INVALID'
	code = ''
	missing_manager := &praxo.SubagentManager{}
	missing_manager.run(praxo.subagent_request('parent', 'child', 'look up')) or {
		code = praxo.error_code(err)
		praxo.SubagentTask{}
	}
	assert code == 'SUBAGENT_INVALID'
}

fn test_mcp() {
	transport := fn (method string, params map[string]json2.Any) !map[string]json2.Any {
		match method {
			'initialize' {
				mut result := map[string]json2.Any{}
				result['protocolVersion'] = json2.Any('2024-11-05')
				return result
			}
			'tools/list' {
				mut schema := map[string]json2.Any{}
				schema['type'] = json2.Any('object')
				mut tool := map[string]json2.Any{}
				tool['name'] = json2.Any('echo')
				tool['description'] = json2.Any('Echo input')
				tool['inputSchema'] = json2.Any(schema)
				mut tools := map[string]json2.Any{}
				tools['tools'] = json2.Any([tool])
				return tools
			}
			'tools/call' {
				mut text := map[string]json2.Any{}
				text['type'] = json2.Any('text')
				text['text'] = json2.Any('ok')
				mut result := map[string]json2.Any{}
				result['content'] = json2.Any([text])
				return result
			}
			else {
				return map[string]json2.Any{}
			}
		}
	}
	mut client := praxo.mcp_client(praxo.McpOptions{ transport: transport }) or { panic(err) }
	tools := client.list_tools() or { panic(err) }
	assert tools.len == 1
	assert (praxo.as_string(tools[0]['name'] or { json2.Any('') }) or { '' }) == 'echo'
	value := client.call_tool('echo', map[string]json2.Any{}) or { panic(err) }
	assert (praxo.as_string(value) or { '' }) == 'ok'
	client.close()
}

fn allow_all_policy(_kind string) bool {
	return true
}

fn test_agent_safe_defaults() {
	model := praxo.static_model('ok')

	mut options := praxo.agent_options(model)
	options.require_policy = true
	mut code := ''
	praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'hello') or {
		code = praxo.error_code(err)
		praxo.RunResult{}
	}
	assert code == 'AGENT_INVALID_OPTIONS'

	options = praxo.agent_options(model)
	options.require_policy = true
	options.policy = allow_all_policy
	policy_result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'hello') or { panic(err) }
	assert policy_result.output == 'ok'

	options = praxo.agent_options(model)
	options.require_tool_scope = true
	code = ''
	praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'hello') or {
		code = praxo.error_code(err)
		praxo.RunResult{}
	}
	assert code == 'AGENT_INVALID_OPTIONS'

	options = praxo.agent_options(model)
	options.require_tool_scope = true
	options.allowed_tools = ['echo']
	scope_result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'hello') or { panic(err) }
	assert scope_result.output == 'ok'

	defaults := praxo.agent_options(model)
	assert !defaults.require_policy
	assert !defaults.require_tool_scope
	assert defaults.allowed_tools.len == 0
	default_result := praxo.run_agent(defaults, praxo.session('s1', []praxo.Message{}), 'hello') or { panic(err) }
	assert default_result.output == 'ok'
}

fn hitl_model(request praxo.Request) !praxo.Response {
	last := request.messages[request.messages.len - 1]
	if last.role == praxo.role_tool {
		return praxo.response(praxo.message_assistant('done', []praxo.ToolCall{}),
			praxo.usage(0, 0))
	}
	return praxo.response(praxo.message_assistant('', [
		praxo.tool_call('write-note-1', 'write_note', {
			'text': json2.Any('hello')
			'visibility': json2.Any('public')
		}),
	]), praxo.usage(0, 0))
}

fn hitl_policy(action praxo.Action) praxo.Decision {
	if action.kind == 'model.generate' {
		return praxo.decision(true, '')
	}
	if action.kind == 'tool.invoke' {
		visibility := praxo.as_string(action.arguments['visibility'] or { json2.null }) or { '' }
		return praxo.decision(action.tool_name == 'write_note' && visibility == 'public',
			'only public notes are permitted')
	}
	return praxo.decision(false, 'unsupported action')
}

fn hitl_run(decision praxo.InterruptDecision, with_handler bool) (string, int, string, []string) {
	mut tool := praxo.func_tool('write_note', 'Write a short note with the requested visibility.')
	tool.invoke = fn (_arguments map[string]json2.Any) json2.Any {
		return json2.Any('written')
	}
	mut options := praxo.agent_options(praxo.callback_model(hitl_model))
	options.tools = [tool]
	options.allowed_tools = ['write_note']
	options.max_steps = 3
	options.policy_action = hitl_policy
	options.interrupt_on = ['write_note']
	if with_handler {
		options.on_interrupt_decision = fn [decision] (_interrupt praxo.Interrupt) praxo.InterruptDecision {
			return decision
		}
	}
	sink := &praxo.Sink{}
	options.events = sink
	mut failure := ''
	result := praxo.run_agent(options, praxo.session('hitl', []praxo.Message{}), 'Write a note.') or {
		failure = praxo.error_code(err)
		praxo.RunResult{}
	}
	return result.output, tool.calls, failure, sink.kinds
}

fn test_agent_hitl_approve() {
	output, calls, failure, kinds := hitl_run(praxo.InterruptDecision{
		action: praxo.interrupt_approve
	}, true)
	assert failure == ''
	assert output == 'done'
	assert calls == 1
	assert kinds == ['run.started', 'tool.interrupt', 'tool.call', 'run.completed']
}

fn test_agent_hitl_edit_reauth_denied() {
	output, calls, failure, kinds := hitl_run(praxo.InterruptDecision{
		action: praxo.interrupt_edit
		arguments: {
			'text': json2.Any('hello')
			'visibility': json2.Any('private')
		}
	}, true)
	assert failure == 'AGENT_POLICY_DENIED'
	assert output == ''
	assert calls == 0
	assert kinds == ['run.started', 'tool.interrupt', 'run.failed']
}

fn test_agent_hitl_reject() {
	output, calls, failure, kinds := hitl_run(praxo.InterruptDecision{
		action: praxo.interrupt_reject
		reason: 'not allowed'
	}, true)
	assert failure == 'AGENT_APPROVAL_DENIED'
	assert output == ''
	assert calls == 0
	assert kinds == ['run.started', 'tool.interrupt', 'run.failed']
}

fn test_agent_hitl_respond() {
	output, calls, failure, kinds := hitl_run(praxo.InterruptDecision{
		action: praxo.interrupt_respond
		response: 'skipped'
	}, true)
	assert failure == ''
	assert output == 'done'
	assert calls == 0
	assert kinds == ['run.started', 'tool.interrupt', 'run.completed']
}

fn test_agent_hitl_unhandled() {
	output, calls, failure, kinds := hitl_run(praxo.InterruptDecision{}, false)
	assert failure == 'AGENT_INTERRUPT_UNHANDLED'
	assert output == ''
	assert calls == 0
	assert kinds == ['run.started', 'run.failed']
}

fn test_agent_hitl_invalid() {
	_, invalid_calls, invalid_failure, invalid_kinds := hitl_run(praxo.InterruptDecision{
		action: 'bogus'
	}, true)
	assert invalid_failure == 'AGENT_INTERRUPT_DECISION_INVALID'
	assert invalid_calls == 0
	assert invalid_kinds == ['run.started', 'tool.interrupt', 'run.failed']
	_, edit_calls, edit_failure, edit_kinds := hitl_run(praxo.InterruptDecision{
		action: praxo.interrupt_edit
	}, true)
	assert edit_failure == 'AGENT_INTERRUPT_DECISION_INVALID'
	assert edit_calls == 0
	assert edit_kinds == ['run.started', 'tool.interrupt', 'run.failed']
}

fn main() {
	test_json()
	test_toolcall()
	test_jsonschema()
	test_plugin()
	test_memory()
	test_checkpoint()
	test_path_normalization()
	test_context()
	test_pii()
	test_agent()
	test_run_ids()
	test_agent_tool()
	test_agent_tool_selection()
	test_callback_model()
	test_agent_middleware()
	test_agent_call_limits()
	test_agent_safe_defaults()
	test_agent_hitl_approve()
	test_agent_hitl_edit_reauth_denied()
	test_agent_hitl_reject()
	test_agent_hitl_respond()
	test_agent_hitl_unhandled()
	test_agent_hitl_invalid()
	test_openai_compatible()
	test_anthropic_compatible()
	test_gemini_compatible()
	test_harmovela()
	test_otel_sink()
	test_retriever()
	test_delegation()
	test_mcp()
	println('v tests passed')
}
