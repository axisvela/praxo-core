module main

import praxo
import x.json2

struct DemoState {
mut:
	effects map[string]int
	child_calls int
}

fn demo_parent_policy(action praxo.Action) praxo.Decision {
	if action.kind == 'model.generate' {
		return praxo.decision(true, '')
	}
	if action.kind == 'tool.invoke' && action.tool_name == 'delegate' {
		return praxo.decision(true, '')
	}
	return praxo.decision(false, 'parent may only delegate')
}

fn demo_child_policy(action praxo.Action) praxo.Decision {
	if action.kind == 'model.generate' {
		return praxo.decision(true, '')
	}
	if action.kind == 'tool.invoke' && action.tool_name == 'record' {
		return praxo.decision(true, '')
	}
	return praxo.decision(false, 'child may only record')
}

fn record_call(id string, target string) praxo.ToolCall {
	return praxo.tool_call(id, 'record', {
		'target': json2.Any(target)
	})
}

fn main() {
	mut state := &DemoState{
		effects: map[string]int{}
	}
	record := &praxo.Tool{
		name: 'record'
		description: 'Record a target in an in-memory counter'
		invoke: fn [mut state] (arguments map[string]json2.Any) json2.Any {
			target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
			state.effects[target] = (state.effects[target] or { 0 }) + 1
			return json2.Any('recorded:${target}')
		}
	}
	child_model := praxo.callback_model(fn [mut state] (request praxo.Request) !praxo.Response {
		state.child_calls++
		if state.child_calls == 1 {
			return praxo.response(praxo.message_assistant('', [record_call('child-record', 'child')]), praxo.usage(0, 0))
		}
		return praxo.response(praxo.message_assistant('child done', []), praxo.usage(0, 0))
	})
	delegate := &praxo.Tool{
		name: 'delegate'
		description: 'Run a child agent with a narrowed record scope'
		invoke: fn [record, child_model] (arguments map[string]json2.Any) json2.Any {
			mut options := praxo.agent_options(child_model)
			options.tools = [record]
			options.max_steps = 3
			options.allowed_tools = ['record']
			options.policy_action = demo_child_policy
			options.require_policy = true
			options.require_tool_scope = true
			result := praxo.run_agent(options, praxo.session('demo-child', []), 'record child') or {
				return json2.Any(err.msg())
			}
			return json2.Any(result.output)
		}
	}
	parent_model := praxo.scripted_model([
		praxo.response(praxo.message_assistant('', [
			praxo.tool_call('parent-delegate', 'delegate', {
				'task': json2.Any('record child')
			}),
		]), praxo.usage(0, 0)),
		praxo.response(praxo.message_assistant('parent done', []), praxo.usage(0, 0)),
	])
	mut options := praxo.agent_options(parent_model)
	options.tools = [record, delegate]
	options.allowed_tools = ['delegate']
	options.policy_action = demo_parent_policy
	options.require_policy = true
	options.require_tool_scope = true
	result := praxo.run_agent(options, praxo.session('demo-parent', []), 'delegate') or {
		panic(err)
	}
	println('delegation: child recorded; parent scope enforced')
	assert result.output == 'parent done'
	assert (state.effects['child'] or { 0 }) == 1

	direct_model := praxo.scripted_model([
		praxo.response(praxo.message_assistant('', [record_call('direct-record', 'child')]), praxo.usage(0, 0)),
		praxo.response(praxo.message_assistant('parent done', []), praxo.usage(0, 0)),
	])
	mut direct_options := praxo.agent_options(direct_model)
	direct_options.tools = [record, delegate]
	direct_options.allowed_tools = ['delegate']
	direct_options.policy_action = demo_parent_policy
	direct_options.require_policy = true
	direct_options.require_tool_scope = true
	mut denied := false
	praxo.run_agent(direct_options, praxo.session('demo-direct', []), 'record directly') or {
		denied = true
	}
	println('deny: parent record blocked; child effect unchanged')
	assert denied
	assert (state.effects['child'] or { 0 }) == 1
}
