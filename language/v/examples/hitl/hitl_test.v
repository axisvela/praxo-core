module main

import praxo
import x.json2

fn test_hitl_approve_scenario() {
	output, calls, failure := run_case(praxo.InterruptDecision{
		action: praxo.interrupt_approve
	})
	assert failure == ''
	assert output == 'done'
	assert calls == 1
}

fn test_hitl_edit_scenario_is_denied_before_effect() {
	output, calls, failure := run_case(praxo.InterruptDecision{
		action: praxo.interrupt_edit
		arguments: {
			'text': json2.Any('hello')
			'visibility': json2.Any('private')
		}
	})
	assert failure.contains('AGENT_POLICY_DENIED')
	assert output == ''
	assert calls == 0
}
