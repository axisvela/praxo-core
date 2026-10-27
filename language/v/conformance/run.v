module main

import os
import praxo
import x.json2

const groups = [
	'agent-loop',
	'checkpoint',
	'context',
	'event',
	'jsonschema',
	'memory',
	'middleware',
	'plugin',
	'policy',
	'stream',
	'toolcall',
]

fn check(condition bool, message string) !void {
	if !condition {
		return error(message)
	}
}

fn read_text(path string) string {
	return os.read_file(path) or { panic(err) }
}

fn run_toolcall(input json2.Any, expect json2.Any) !void {
	operation := praxo.get_string(input, 'operation') or { '' }
	content := praxo.get_string(input, 'content') or { '' }
	if operation == 'strip' {
		got := praxo.strip_tool_call_markup(content)
		check(got == (praxo.get_string(expect, 'text') or { '' }), 'strip: got ${got}')!
		return
	}
	call := praxo.parse_tool_call(content)
	if praxo.get_bool(expect, 'nil', false) {
		if call != none {
			return error('expected nil')
		}
		return
	}
	value := call or { return error('expected a tool call') }
	check(value.name == (praxo.get_string(expect, 'name') or { '' }), 'name: got ${value.name}')!
	expected := praxo.get(expect, 'input') or { json2.Any(map[string]json2.Any{}) }
	check(praxo.json_equals(json2.Any(value.arguments), expected), 'input mismatch')!
}

fn run_jsonschema(input json2.Any, expect json2.Any) !void {
	schema := praxo.get(input, 'schema') or { json2.null }
	data := praxo.get(input, 'data') or { json2.null }
	errors := praxo.validate_schema(schema, data)
	mut paths := []string{cap: errors.len}
	for item in errors {
		paths << item.path
	}
	paths.sort()
	mut expected := []string{}
	for item in praxo.get_array(expect, 'errorPaths') {
		if path := praxo.as_string(item) {
			expected << path
		}
	}
	expected.sort()
	check((errors.len == 0) == praxo.get_bool(expect, 'valid', false), 'valid mismatch')!
	check(praxo.json_equals(praxo.json_from_strings(paths), praxo.json_from_strings(expected)),
		'errorPaths: got ${paths.join(', ')}')!
}

fn run_plugin(input json2.Any, expect json2.Any) !void {
	raw := praxo.get_string(input, 'raw') or {
		praxo.encode_json(praxo.get(input, 'manifest') or { json2.null })
	}
	mut code := ''
	manifest := praxo.parse_manifest(raw) or {
		code = 'PLUGIN_INVALID'
		praxo.Manifest{}
	}
	check((code == '') == praxo.get_bool(expect, 'valid', false), 'valid mismatch')!
	if code != '' {
		return
	}
	if id := praxo.get_string(expect, 'id') {
		check(manifest.id == id, 'id: got ${manifest.id}')!
	}
	if kind := praxo.get_string(expect, 'kind') {
		check(manifest.kind == kind, 'kind: got ${manifest.kind}')!
	}
}

fn run_memory(input json2.Any, expect json2.Any) !void {
	mut store := praxo.memory_store()
	for put in praxo.get_array(input, 'puts') {
		session_id := praxo.get_string(put, 'session') or { '' }
		record := praxo.get(put, 'record') or { json2.null }
		store.put(session_id, praxo.memory_record(
			praxo.get_string(record, 'id') or { '' }
			praxo.get_string(record, 'frame') or { '' }
			praxo.get_string(record, 'content') or { '' }
			praxo.get_string(record, 'createdAt') or { '' }
		))
	}
	records := store.search(
		praxo.get_string(input, 'session') or { '' }
		praxo.get_string(input, 'query') or { '' }
		praxo.get_int(input, 'limit', 0)
	)
	mut ids := json2.Any(json2.null)
	mut contents := json2.Any(json2.null)
	if records.len > 0 {
		mut id_values := []string{}
		mut content_values := []string{}
		for record in records {
			id_values << record.id
			content_values << record.content
		}
		ids = praxo.json_from_strings(id_values)
		contents = praxo.json_from_strings(content_values)
	}
	check(praxo.json_equals(ids, praxo.get(expect, 'ids') or { json2.null }), 'ids mismatch')!
	check(praxo.json_equals(contents, praxo.get(expect, 'contents') or { json2.null }),
		'contents mismatch')!
}

fn run_event(input json2.Any, expect json2.Any) !void {
	mut events := []praxo.Event{}
	for kind in praxo.get_array(input, 'events') {
		if item := praxo.as_string(kind) {
			events << praxo.event(item, 's1')
		}
	}
	if (praxo.get_string(input, 'sink') or { 'filter' }) == 'multi' {
		count := if praxo.get_int(input, 'sinkCount', 1) > 0 {
			praxo.get_int(input, 'sinkCount', 1)
		} else {
			1
		}
		mut sinks := []&praxo.Sink{}
		for _ in 0 .. count {
			sinks << &praxo.Sink{}
		}
		mut multi := praxo.multi_sink(sinks)
		for item in events {
			multi.emit(item)
		}
		mut per_sink := []json2.Any{cap: sinks.len}
		for sink in sinks {
			per_sink << praxo.json_from_strings(sink.kinds)
		}
		check(praxo.json_equals(json2.Any(per_sink), praxo.get(expect, 'perSink') or { json2.null }),
			'perSink mismatch')!
		return
	}
	base := &praxo.Sink{}
	mut predicate := []string{}
	for item in praxo.get_array(input, 'predicateTypes') {
		if value := praxo.as_string(item) {
			predicate << value
		}
	}
	mut filter := praxo.filter_sink(base, predicate)
	for item in events {
		filter.emit(item)
	}
	delivered := if base.kinds.len > 0 {
		praxo.json_from_strings(base.kinds)
	} else {
		json2.null
	}
	check(praxo.json_equals(delivered, praxo.get(expect, 'delivered') or { json2.null }),
		'delivered mismatch')!
}

fn run_stream(expect json2.Any) !void {
	check(praxo.json_equals(praxo.json_from_strings(praxo.stream_kinds),
		praxo.get(expect, 'kinds') or { json2.null }), 'kinds mismatch')!
}

fn run_checkpoint(input json2.Any, expect json2.Any) !void {
	mut allow := praxo.checkpoint_allowlist()
	for kind in praxo.get_array(input, 'registered') {
		if value := praxo.as_string(kind) {
			allow.register(value)!
		}
	}
	operation := praxo.get_string(input, 'operation') or { 'roundtrip' }
	kind := praxo.get_string(input, 'type') or { '' }
	value := praxo.get(input, 'value') or { json2.null }
	if operation == 'roundtrip' {
		data := allow.marshal(kind, value)!
		result := allow.unmarshal(data)!
		check(praxo.json_equals(result, praxo.get(expect, 'value') or { json2.null }),
			'value mismatch')!
		return
	}
	mut code := ''
	if operation == 'marshal' {
		allow.marshal(kind, value) or {
			code = praxo.error_code(err)
			''
		}
	} else if operation == 'unmarshal' {
		mut envelope := map[string]json2.Any{}
		envelope['type'] = json2.Any(kind)
		envelope['data'] = value
		allow.unmarshal(praxo.encode_json(json2.Any(envelope))) or {
			code = praxo.error_code(err)
			json2.null
		}
	} else {
		code = 'CHECKPOINT_ERROR'
	}
	check(code == (praxo.get_string(expect, 'errorCode') or { '' }), 'errorCode: got ${code}')!
}

fn run_policy(input json2.Any, expect json2.Any) !void {
	mut grants := []praxo.PathGrant{}
	for item in praxo.get_array(input, 'grants') {
		grants << praxo.path_grant(
			praxo.get_string(item, 'root') or { '' }
			praxo.get_string(item, 'access') or { 'read' }
		)
	}
	checker := praxo.path_checker(grants)!
	target := praxo.get_string(input, 'target') or { '' }
	need := praxo.get_string(input, 'need') or { 'read' }
	if praxo.get_bool(expect, 'error', false) {
		_ := checker.check(target, need) or {
			check(true, 'expected a policy error')!
			praxo.Decision{}
		}
		return
	}
	decision := checker.check(target, need)!
	check(decision.allowed == praxo.get_bool(expect, 'allowed', false), 'allowed mismatch')!
}

fn run_context(input json2.Any, expect json2.Any) !void {
	mut messages := []praxo.Message{}
	for item in praxo.get_array(input, 'messages') {
		messages << praxo.message(
			praxo.get_string(item, 'role') or { '' }
			praxo.get_string(item, 'content') or { '' }
		)
	}
	if (praxo.get_string(input, 'operation') or { '' }) == 'estimate' {
		tokens := praxo.estimate_tokens(messages)
		check(tokens == praxo.get_int(expect, 'tokens', 0), 'tokens: got ${tokens}')!
		return
	}
	budget_value := praxo.get(input, 'budget') or { json2.null }
	budget := praxo.context_budget(
		praxo.get_int(budget_value, 'maxTokens', 0)
		praxo.get_int(budget_value, 'keepRecent', 0)
	)
	output, ok := praxo.compact_context(budget, messages)
	check(ok == praxo.get_bool(expect, 'ok', false), 'ok mismatch')!
	if !ok {
		return
	}
	tokens := praxo.estimate_tokens(output)
	check(tokens == praxo.get_int(expect, 'tokens', 0), 'tokens: got ${tokens}')!
	mut wire := []json2.Any{cap: output.len}
	for item in output {
		wire << json2.Any(praxo.message_wire(item))
	}
	check(praxo.json_equals(json2.Any(wire), praxo.get(expect, 'messages') or { json2.null }),
		'messages mismatch')!
}

fn run_middleware(input json2.Any, expect json2.Any) !void {
	operation := praxo.get_string(input, 'operation') or { '' }
	if operation == 'pii' {
		got := praxo.pii_redact(praxo.get_string(input, 'text') or { '' })
		check(got == (praxo.get_string(expect, 'text') or { '' }), 'text mismatch')!
	} else if operation == 'pii-value' {
		value := praxo.get(input, 'value') or { json2.null }
		check(praxo.json_equals(praxo.redact_value(value),
			praxo.get(expect, 'value') or { json2.null }), 'value mismatch')!
	} else if operation == 'structured' {
		schema := praxo.get(input, 'schema') or { json2.null }
		mut config := praxo.structured_output(schema, praxo.get_int(input, 'maxRepairs', 0), none)
		if repair := praxo.get_string(input, 'repairOutput') {
			config.repairer = fn [repair] (text string) string {
				return repair
			}
		}
		output, code := config.apply(praxo.get_string(input, 'output') or { '' })
		if praxo.get_bool(expect, 'ok', false) {
			check(code == '' && output == (praxo.get_string(expect, 'output') or { '' }),
				'output mismatch')!
		} else {
			check(code == (praxo.get_string(expect, 'errorCode') or { '' }), 'errorCode mismatch')!
		}
	} else if operation == 'call-limit' {
		mut limit := praxo.call_limit(
			praxo.get_int(input, 'modelLimit', 0)
			praxo.get_int(input, 'toolLimit', 0)
		)
		mut outcomes := []string{}
		for call in praxo.get_array(input, 'calls') {
			kind := praxo.as_string(call) or { '' }
			mut code := 'ok'
			if kind == 'model' {
				limit.model_call() or { code = praxo.error_code(err) }
			} else {
				limit.tool_call() or { code = praxo.error_code(err) }
			}
			outcomes << code
		}
		check(praxo.json_equals(praxo.json_from_strings(outcomes),
			praxo.get(expect, 'outcomes') or { json2.null }), 'outcomes mismatch')!
	} else if operation == 'tool-selection' {
		mut selected := []string{}
		for item in praxo.get_array(input, 'selected') {
			if value := praxo.as_string(item) {
				selected << value
			}
		}
		selection := praxo.tool_selection(selected)
		mut tools := []praxo.ToolSpec{}
		for item in praxo.get_array(input, 'tools') {
			tools << praxo.tool_spec(praxo.as_string(item) or { '' }, '')
		}
		advertised := praxo.select_tools(selection, tools)
		mut names := []string{}
		for item in advertised {
			names << item.name
		}
		check(praxo.json_equals(praxo.json_from_strings(names),
			praxo.get(expect, 'advertised') or { json2.null }), 'advertised mismatch')!
		mut reject := 'ok'
		praxo.check_tool_selected(selection, praxo.get_string(input, 'requested') or { '' }) or {
			reject = praxo.error_code(err)
		}
		check(reject == (praxo.get_string(expect, 'reject') or { '' }), 'reject mismatch')!
	} else if operation == 'fallback' {
		content := praxo.get_string(input, 'fallbackContent') or { '' }
		mut model := praxo.fallback_model(praxo.failing_model(), praxo.static_model(content))
		result := model.generate(praxo.request([]praxo.Message{}, []praxo.ToolSpec{}))!
		check(result.message.content == content, 'output mismatch')!
	}
}

fn run_agent_loop(input json2.Any, expect json2.Any) !void {
	mut tools := []&praxo.Tool{}
	for item in praxo.get_array(input, 'tools') {
		tools << praxo.func_tool(
			praxo.get_string(item, 'name') or { '' }
			praxo.get_string(item, 'description') or { '' }
		)
	}
	mut script := []praxo.Response{}
	for item in praxo.get_array(input, 'script') {
		mut calls := []praxo.ToolCall{}
		for call in praxo.get_array(item, 'toolCalls') {
			calls << praxo.tool_call(
				praxo.get_string(call, 'id') or { '' }
				praxo.get_string(call, 'name') or { '' }
				praxo.as_object(praxo.get(call, 'arguments') or { json2.null })
			)
		}
		script << praxo.response(
			praxo.message_assistant(praxo.get_string(item, 'content') or { '' }, calls)
			praxo.usage(
				praxo.get_int(item, 'inputTokens', 0)
				praxo.get_int(item, 'outputTokens', 0)
			)
		)
	}
	model := praxo.scripted_model(script)
	mut options := praxo.agent_options(model)
	options.tools = tools
	options.max_steps = praxo.get_int(input, 'maxSteps', 0)
	options.max_tokens = praxo.get_int(input, 'maxTokens', 0)
	sink := &praxo.Sink{}
	options.events = sink
	session_value := praxo.session('s1', []praxo.Message{})
	mut failure := ''
	result := praxo.run_agent(options, session_value,
		praxo.get_string(input, 'prompt') or { '' }) or {
		failure = praxo.error_code(err)
		praxo.RunResult{}
	}
	if praxo.get_bool(expect, 'error', false) {
		check(failure != '', 'unexpected success')!
		if expected := praxo.get_string(expect, 'errorCode') {
			check(failure == expected, 'errorCode: got ${failure}')!
		}
	} else {
		check(failure == '', 'unexpected failure: ${failure}')!
		check(result.output == (praxo.get_string(expect, 'output') or { '' }), 'output mismatch')!
		check(result.steps == praxo.get_int(expect, 'steps', 0), 'steps mismatch')!
	}
	mut invocations := 0
	for tool in tools {
		invocations += tool.calls
	}
	check(invocations == praxo.get_int(expect, 'toolInvocations', 0),
		'tool invocations mismatch')!
	events := if sink.kinds.len > 0 {
		praxo.json_from_strings(sink.kinds)
	} else {
		json2.null
	}
	check(praxo.json_equals(events, praxo.get(expect, 'events') or { json2.null }),
		'events mismatch')!
}

fn run_vector(group string, vector json2.Any) !void {
	input := praxo.get(vector, 'input') or { json2.Any(map[string]json2.Any{}) }
	expect := praxo.get(vector, 'expect') or { json2.Any(map[string]json2.Any{}) }
	if group == 'toolcall' {
		run_toolcall(input, expect)!
	} else if group == 'jsonschema' {
		run_jsonschema(input, expect)!
	} else if group == 'plugin' {
		run_plugin(input, expect)!
	} else if group == 'memory' {
		run_memory(input, expect)!
	} else if group == 'event' {
		run_event(input, expect)!
	} else if group == 'stream' {
		run_stream(expect)!
	} else if group == 'checkpoint' {
		run_checkpoint(input, expect)!
	} else if group == 'policy' {
		run_policy(input, expect)!
	} else if group == 'context' {
		run_context(input, expect)!
	} else if group == 'middleware' {
		run_middleware(input, expect)!
	} else if group == 'agent-loop' {
		run_agent_loop(input, expect)!
	} else {
		return error('no runner for group ${group}')
	}
}

fn main() {
	version := read_text('spec/SPEC_VERSION').trim_space()
	mut failures := []string{}
	mut seen := map[string]string{}
	for group in groups {
		content := read_text('spec/vectors/${group}.json')
		file := praxo.parse_json(content) or {
			failures << '${group}: invalid vector file'
			continue
		}
		if (praxo.get_string(file, 'group') or { '' }) != group {
			failures << '${group}: group mismatch'
		}
		if (praxo.get_string(file, 'specVersion') or { '' }) != version {
			failures << '${group}: specVersion mismatch'
		}
		for vector in praxo.get_array(file, 'vectors') {
			id := praxo.get_string(vector, 'id') or { '' }
			if previous := seen[id] {
				failures << '${group}/${id}: duplicate id with ${previous}'
			}
			seen[id] = group
			run_vector(group, vector) or {
				failures << '${group}/${id}: ${err.msg()}'
				continue
			}
		}
	}
	if failures.len == 0 {
		println('all spec vectors passed')
		return
	}
	for failure in failures {
		eprintln(failure)
	}
	exit(1)
}
