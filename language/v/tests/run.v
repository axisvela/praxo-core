module main

import praxo
import x.json2

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
	test_agent_tool()
	test_agent_tool_selection()
	test_callback_model()
	println('v tests passed')
}
