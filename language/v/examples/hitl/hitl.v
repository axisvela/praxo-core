module main

import praxo
import x.json2

fn fixture_model(request praxo.Request) !praxo.Response {
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

fn allow_public(action praxo.Action) praxo.Decision {
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

fn run_case(decision praxo.InterruptDecision) (string, int, string) {
	mut tool := praxo.func_tool('write_note', 'Write a short note with the requested visibility.')
	tool.invoke = fn (_arguments map[string]json2.Any) json2.Any {
		return json2.Any('written')
	}
	mut options := praxo.agent_options(praxo.callback_model(fixture_model))
	options.tools = [tool]
	options.max_steps = 3
	options.allowed_tools = ['write_note']
	options.policy_action = allow_public
	options.interrupt_on = ['write_note']
	options.on_interrupt_decision = fn [decision] (_interrupt praxo.Interrupt) praxo.InterruptDecision {
		return decision
	}
	result := praxo.run_agent(options, praxo.session('hitl', []praxo.Message{}),
		'Write a note.') or { return '', tool.calls, err.msg() }
	return result.output, tool.calls, ''
}

fn main() {
	approve_output, approve_calls, approve_failure := run_case(praxo.InterruptDecision{
		action: praxo.interrupt_approve
	})
	if approve_failure != '' || approve_output != 'done' || approve_calls != 1 {
		eprintln('approve verification failed: output=${approve_output} effects=${approve_calls} error=${approve_failure}')
		exit(1)
	}
	println('approve: written; effects=1')

	edit_output, edit_calls, edit_failure := run_case(praxo.InterruptDecision{
		action: praxo.interrupt_edit
		arguments: {
			'text': json2.Any('hello')
			'visibility': json2.Any('private')
		}
	})
	if edit_failure == '' || !edit_failure.contains('AGENT_POLICY_DENIED') || edit_calls != 0
		|| edit_output != '' {
		eprintln('edit verification failed: output=${edit_output} effects=${edit_calls} error=${edit_failure}')
		exit(1)
	}
	println('edit: policy rejected; effects=0')
}
