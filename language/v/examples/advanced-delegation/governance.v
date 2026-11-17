module main

import praxo
import x.json2

struct GovState {
mut:
	effects  map[string]int
	budget   int
	children int
}

struct RunConfig {
	allowed         []string
	policy          ?praxo.PolicyActionHook
	tools           []&praxo.Tool
	depth           int
	max_depth       int = -1
	max_children    int = -1
	use_budget      bool
	use_children    bool
	cancelled       bool
	edit_to_blocked bool
}

fn allow() praxo.Decision {
	return praxo.decision(true, '')
}

fn deny(reason string) praxo.Decision {
	return praxo.decision(false, reason)
}

fn target_of(action praxo.Action) string {
	arguments := praxo.as_object(json2.Any(action.arguments))
	return praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
}

fn permissive_record(action praxo.Action) praxo.Decision {
	if action.kind == 'model.generate' {
		return allow()
	}
	if action.kind == 'tool.invoke' && action.tool_name == 'record' {
		return allow()
	}
	return deny('child may only record')
}

fn parent_deny_blocked(action praxo.Action) praxo.Decision {
	if action.kind == 'model.generate' {
		return allow()
	}
	if action.kind != 'tool.invoke' || action.tool_name != 'record' {
		return deny('parent tool is not allowed')
	}
	if target_of(action) == 'blocked' {
		return deny('blocked target')
	}
	return allow()
}

fn composed_policy(action praxo.Action) praxo.Decision {
	parent := parent_deny_blocked(action)
	if !parent.allowed {
		return parent
	}
	return permissive_record(action)
}

fn denied_task(status string, code string) praxo.SubagentTask {
	return praxo.SubagentTask{
		id: 'subagent'
		status: status
		error: code
	}
}

fn run_child(mut state GovState, model &praxo.Model, config RunConfig) praxo.SubagentTask {
	if config.cancelled {
		return denied_task('cancelled', 'CANCELLED')
	}
	if config.max_depth >= 0 && config.depth > config.max_depth {
		return denied_task('denied', 'DEPTH_LIMIT')
	}
	if config.max_children >= 0 && state.children >= config.max_children {
		return denied_task('denied', 'CHILD_LIMIT')
	}
	if config.use_budget && state.budget <= 0 {
		return denied_task('denied', 'BUDGET_EXHAUSTED')
	}
	if config.use_children {
		state.children++
	}
	mut options := praxo.agent_options(model)
	options.tools = config.tools
	options.max_steps = 3
	options.allowed_tools = config.allowed
	if hook := config.policy {
		options.policy_action = hook
	}
	options.require_policy = true
	options.require_tool_scope = true
	if config.edit_to_blocked {
		options.interrupt_on = ['record']
		options.on_interrupt_decision = fn (interrupt praxo.Interrupt) praxo.InterruptDecision {
			return praxo.InterruptDecision{
				action: praxo.interrupt_edit
				arguments: {
					'target': json2.Any('blocked')
				}
			}
		}
	}
	task := praxo.subagent_run(fn [options] (request praxo.SubagentRequest) !praxo.SubagentResult {
		result := praxo.run_agent(options, praxo.session('governance-child', []), 'run child')!
		return praxo.subagent_result('child', 'child', result.output)
	}, praxo.subagent_request('governance-parent', 'governance-child', 'run child')) or {
		return denied_task('failed', err.msg())
	}
	if config.use_budget && task.status == 'completed' {
		state.budget--
	}
	return task
}

fn model_for(tool string, target string) &praxo.Model {
	return praxo.scripted_model([
		praxo.response(praxo.message_assistant('', [
			praxo.tool_call('call-1', tool, {
				'target': json2.Any(target)
			}),
		]), praxo.usage(0, 0)),
		praxo.response(praxo.message_assistant('done', []), praxo.usage(0, 0)),
	])
}

fn main() {
	// 1. Child scope narrowing: write is not in the allowed scope.
	mut scope_state := &GovState{
		effects: map[string]int{}
	}
	scope_tools := [
		&praxo.Tool{
			name: 'record'
			description: 'record'
			invoke: fn [mut scope_state] (arguments map[string]json2.Any) json2.Any {
				target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
				scope_state.effects[target] = (scope_state.effects[target] or { 0 }) + 1
				return json2.Any('ok')
			}
		},
		&praxo.Tool{
			name: 'write'
			description: 'write'
			invoke: fn [mut scope_state] (arguments map[string]json2.Any) json2.Any {
				target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
				scope_state.effects[target] = (scope_state.effects[target] or { 0 }) + 1
				return json2.Any('ok')
			}
		},
	]
	scope := run_child(mut scope_state, model_for('write', 'escape'), RunConfig{
		allowed: ['record']
		policy: permissive_record
		tools: scope_tools
	})
	assert scope.status == 'failed'
	assert (scope_state.effects['escape'] or { 0 }) == 0

	// 2. Parent policy composition wins over child allow.
	mut policy_state := &GovState{
		effects: map[string]int{}
	}
	policy_tools := [
		&praxo.Tool{
			name: 'record'
			description: 'record'
			invoke: fn [mut policy_state] (arguments map[string]json2.Any) json2.Any {
				target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
				policy_state.effects[target] = (policy_state.effects[target] or { 0 }) + 1
				return json2.Any('ok')
			}
		},
	]
	composed := run_child(mut policy_state, model_for('record', 'blocked'), RunConfig{
		allowed: ['record']
		policy: composed_policy
		tools: policy_tools
	})
	assert composed.status == 'failed'
	assert (policy_state.effects['blocked'] or { 0 }) == 0

	// 3. Shared sibling budget.
	mut budget_state := &GovState{
		effects: map[string]int{}
		budget: 1
	}
	budget_tools := [
		&praxo.Tool{
			name: 'record'
			description: 'record'
			invoke: fn [mut budget_state] (arguments map[string]json2.Any) json2.Any {
				target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
				budget_state.effects[target] = (budget_state.effects[target] or { 0 }) + 1
				return json2.Any('ok')
			}
		},
	]
	first := run_child(mut budget_state, model_for('record', 'sibling'), RunConfig{
		allowed: ['record']
		policy: permissive_record
		tools: budget_tools
		use_budget: true
	})
	second := run_child(mut budget_state, model_for('record', 'sibling'), RunConfig{
		allowed: ['record']
		policy: permissive_record
		tools: budget_tools
		use_budget: true
	})
	assert first.status == 'completed'
	assert second.status == 'denied'
	assert second.error == 'BUDGET_EXHAUSTED'
	assert (budget_state.effects['sibling'] or { 0 }) == 1

	// 4. Child-count and depth limits.
	mut limit_state := &GovState{
		effects: map[string]int{}
	}
	limit_tools := [
		&praxo.Tool{
			name: 'record'
			description: 'record'
			invoke: fn [mut limit_state] (arguments map[string]json2.Any) json2.Any {
				target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
				limit_state.effects[target] = (limit_state.effects[target] or { 0 }) + 1
				return json2.Any('ok')
			}
		},
	]
	first_limit := run_child(mut limit_state, model_for('record', 'limit'), RunConfig{
		allowed: ['record']
		policy: permissive_record
		tools: limit_tools
		max_children: 1
		use_children: true
	})
	second_limit := run_child(mut limit_state, model_for('record', 'limit'), RunConfig{
		allowed: ['record']
		policy: permissive_record
		tools: limit_tools
		max_children: 1
		use_children: true
	})
	deep := run_child(mut limit_state, model_for('record', 'limit'), RunConfig{
		allowed: ['record']
		policy: permissive_record
		tools: limit_tools
		depth: 2
		max_depth: 1
	})
	assert first_limit.status == 'completed'
	assert second_limit.error == 'CHILD_LIMIT'
	assert deep.error == 'DEPTH_LIMIT'
	assert (limit_state.effects['limit'] or { 0 }) == 1

	// 5. Cancellation before effects.
	mut cancel_state := &GovState{
		effects: map[string]int{}
	}
	cancelled := run_child(mut cancel_state, model_for('record', 'cancel'), RunConfig{
		allowed: ['record']
		policy: permissive_record
		tools: limit_tools
		cancelled: true
	})
	assert cancelled.status == 'cancelled'
	assert (cancel_state.effects['cancel'] or { 0 }) == 0

	// 6. Final-argument reauthorization.
	mut edit_state := &GovState{
		effects: map[string]int{}
	}
	edit_tools := [
		&praxo.Tool{
			name: 'record'
			description: 'record'
			invoke: fn [mut edit_state] (arguments map[string]json2.Any) json2.Any {
				target := praxo.as_string(arguments['target'] or { json2.Any('') }) or { '' }
				edit_state.effects[target] = (edit_state.effects[target] or { 0 }) + 1
				return json2.Any('ok')
			}
		},
	]
	edited := run_child(mut edit_state, model_for('record', 'edit-me'), RunConfig{
		allowed: ['record']
		policy: parent_deny_blocked
		tools: edit_tools
		edit_to_blocked: true
	})
	assert edited.status == 'failed'
	assert (edit_state.effects['edit-me'] or { 0 }) == 0
	assert (edit_state.effects['blocked'] or { 0 }) == 0

	println('V advanced delegation governance: 6/6 passed')
}
