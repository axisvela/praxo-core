module main

import praxo
import x.json2

struct ChainState {
mut:
	effects   map[string]int
	otel      []string
	harmovela []string
	child_calls int
}

fn parent_policy(action praxo.Action) praxo.Decision {
	if action.kind == 'model.generate' {
		return praxo.decision(true, '')
	}
	if action.kind != 'tool.invoke' {
		return praxo.decision(false, 'unsupported action')
	}
	if action.tool_name == 'record' {
		arguments := praxo.as_object(json2.Any(action.arguments))
		target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
		if target == 'blocked' {
			return praxo.decision(false, 'blocked target')
		}
		return praxo.decision(true, '')
	}
	if action.tool_name == 'delegate' {
		return praxo.decision(true, '')
	}
	return praxo.decision(false, 'parent tool is not allowed')
}

fn child_policy(action praxo.Action) praxo.Decision {
	if action.kind == 'model.generate' {
		return praxo.decision(true, '')
	}
	if action.kind == 'tool.invoke' && action.tool_name == 'record' {
		return praxo.decision(true, '')
	}
	return praxo.decision(false, 'child may only record')
}

fn composed_policy(action praxo.Action) praxo.Decision {
	parent := parent_policy(action)
	if !parent.allowed {
		return parent
	}
	return child_policy(action)
}

fn record_call(id string, target string) praxo.ToolCall {
	return praxo.tool_call(id, 'record', {
		'target': json2.Any(target)
	})
}

fn delegate_call(id string) praxo.ToolCall {
	return praxo.tool_call(id, 'delegate', {
		'task': json2.Any('record child')
	})
}

fn response_with(call praxo.ToolCall) praxo.Response {
	return praxo.response(praxo.message_assistant('', [call]), praxo.usage(0, 0))
}

fn final_response(text string) praxo.Response {
	return praxo.response(praxo.message_assistant(text, []), praxo.usage(0, 0))
}

fn main() {
	mut state := &ChainState{
		effects: map[string]int{}
	}
	transport := fn [mut state] (method string, params map[string]json2.Any) !map[string]json2.Any {
		if method == 'initialize' {
			return json2.decode[map[string]json2.Any]('{"protocolVersion":"2024-11-05","serverInfo":{"name":"fake-mcp"}}')!
		}
		if method == 'tools/list' {
			return json2.decode[map[string]json2.Any]('{"tools":[{"name":"record","description":"Record a target","inputSchema":{"type":"object","properties":{"target":{"type":"string"}},"required":["target"]}}]}')!
		}
		if method == 'tools/call' {
			arguments := praxo.as_object(params['arguments'] or {
				json2.Any(map[string]json2.Any{})
			})
			target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
			state.effects[target] = (state.effects[target] or { 0 }) + 1
			mut text := map[string]json2.Any{}
			text['type'] = json2.Any('text')
			text['text'] = json2.Any('recorded:${target}')
			return {
				'content': json2.Any([json2.Any(text)])
			}
		}
		return map[string]json2.Any{}
	}

	mut client := praxo.mcp_client(praxo.McpOptions{
		transport: transport
	}) or { panic(err) }
	tools := client.list_tools() or { panic(err) }
	assert tools.len == 1

	record := &praxo.Tool{
		name: 'record'
		description: 'Record a target through the MCP client'
		invoke: fn [client] (arguments map[string]json2.Any) json2.Any {
			target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
			return client.call_tool('record', {
				'target': json2.Any(target)
			}) or { json2.Any(err.msg()) }
		}
	}

	otel := praxo.otel_sink('http://otel.local/v1/traces', praxo.OtelOptions{
		transport: fn [mut state] (endpoint string, body string, headers map[string]string) !praxo.OtelResponse {
			payload := praxo.parse_json(body) or { json2.Any(map[string]json2.Any{}) }
			payload_obj := praxo.as_object(payload)
			for resource in praxo.as_array(payload_obj['resourceSpans'] or {
				json2.Any([]json2.Any{})
			}) {
				resource_obj := praxo.as_object(resource)
				for scope in praxo.as_array(resource_obj['scopeSpans'] or {
					json2.Any([]json2.Any{})
				}) {
					scope_obj := praxo.as_object(scope)
					for span in praxo.as_array(scope_obj['spans'] or {
						json2.Any([]json2.Any{})
					}) {
						span_obj := praxo.as_object(span)
						name := praxo.as_string(span_obj['name'] or { json2.Any('') }) or { '' }
						state.otel << name
					}
				}
			}
			return praxo.OtelResponse{status: 200, body: ''}
		}
	})
	harmovela := praxo.harmovela_sink('http://harmovela.local', praxo.HarmovelaOptions{
		transport: fn [mut state] (base_url string, path string, body string, headers map[string]string) !praxo.HarmovelaResponse {
			payload := praxo.parse_json(body) or { json2.Any(map[string]json2.Any{}) }
			envelope := praxo.as_object(payload)
			kind := praxo.as_string(envelope['type'] or { json2.Any('') }) or { '' }
			state.harmovela << kind
			return praxo.HarmovelaResponse{status: 202, body: ''}
		}
	})
	events := praxo.multi_sink([otel, harmovela])

	delegate := &praxo.Tool{
		name: 'delegate'
		description: 'Run a governed child agent with the narrowed record scope'
		invoke: fn [mut state, record, events] (arguments map[string]json2.Any) json2.Any {
			child_model := praxo.callback_model(fn [mut state] (request praxo.Request) !praxo.Response {
				state.child_calls++
				if state.child_calls == 1 {
					return response_with(record_call('child-record', 'child'))
				}
				return final_response('DONE')
			})
			mut options := praxo.agent_options(child_model)
			options.tools = [record]
			options.max_steps = 3
			options.allowed_tools = ['record']
			options.policy_action = composed_policy
			options.require_policy = true
			options.require_tool_scope = true
			options.events = events
			result := praxo.run_agent(options, praxo.session('chain-child', []), 'record child') or {
				return json2.Any(err.msg())
			}
			mut output := map[string]json2.Any{}
			output['output'] = json2.Any(result.output)
			output['effects'] = json2.Any(state.effects['child'] or { 0 })
			return json2.Any(output)
		}
	}

	parent_model := praxo.scripted_model([
		response_with(record_call('parent-record', 'parent')),
		response_with(delegate_call('parent-delegate')),
		final_response('DONE'),
	])
	mut options := praxo.agent_options(parent_model)
	options.tools = [record, delegate]
	options.max_steps = 4
	options.allowed_tools = ['record', 'delegate']
	options.policy_action = parent_policy
	options.require_policy = true
	options.require_tool_scope = true
	options.events = events
	parent := praxo.run_agent(options, praxo.session('chain-parent', []), 'record parent, then delegate') or {
		panic(err)
	}

	denied_model := praxo.scripted_model([
		response_with(record_call('denied-record', 'edit-me')),
		final_response('DONE'),
	])
	mut denied_options := praxo.agent_options(denied_model)
	denied_options.tools = [record]
	denied_options.max_steps = 2
	denied_options.allowed_tools = ['record']
	denied_options.policy_action = parent_policy
	denied_options.require_policy = true
	denied_options.require_tool_scope = true
	denied_options.events = events
	denied_options.interrupt_on = ['record']
	denied_options.on_interrupt_decision = fn (interrupt praxo.Interrupt) praxo.InterruptDecision {
		return praxo.InterruptDecision{
			action: praxo.interrupt_edit
			arguments: {
				'target': json2.Any('blocked')
			}
		}
	}
	mut denied_error := ''
	praxo.run_agent(denied_options, praxo.session('chain-denied', []), 'attempt a denied edit') or {
		denied_error = err.msg()
	}

	client.close()
	println('output: ${parent.output}')
	println('effects: parent=${state.effects['parent'] or { 0 }} child=${state.effects['child'] or { 0 }}')
	println('child calls: ${state.child_calls}')
	println('otel spans: ${state.otel.len}')
	println('harmovela events: ${state.harmovela.len}')
	println('denied effects: ${state.effects['blocked'] or { 0 }}')
	assert parent.output == 'DONE'
	assert (state.effects['parent'] or { 0 }) == 1
	assert (state.effects['child'] or { 0 }) == 1
	assert state.child_calls == 2
	assert state.otel.len >= 3
	assert state.harmovela.len >= 3
	assert (state.effects['blocked'] or { 0 }) == 0
	assert denied_error != ''
}
