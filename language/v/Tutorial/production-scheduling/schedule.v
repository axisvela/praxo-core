module main

import os
import praxo
import x.json2

struct Job {
	id       string
	priority int
	due_min  int
}

struct State {
mut:
	reads  int
	drafts int
}

fn fixture_jobs() []Job {
	return [
		Job{'job-a', 2, 30},
		Job{'job-b', 3, 40},
		Job{'job-c', 2, 10},
	]
}

fn recommended_order(jobs []Job) []string {
	mut remaining := jobs.clone()
	mut order := []string{}
	for remaining.len > 0 {
		mut best := 0
		for index in 1 .. remaining.len {
			if remaining[index].priority > remaining[best].priority
				|| (remaining[index].priority == remaining[best].priority
				&& remaining[index].due_min < remaining[best].due_min) {
				best = index
			}
		}
		order << remaining[best].id
		remaining.delete(best)
	}
	return order
}

fn fixture_model(line string) &praxo.Model {
	return praxo.callback_model(fn [line] (request praxo.Request) !praxo.Response {
		mut count := 0
		mut first := json2.Any(map[string]json2.Any{})
		mut last := json2.Any(map[string]json2.Any{})
		for message in request.messages {
			if message.role != praxo.role_tool {
				continue
			}
			parsed := praxo.parse_json(message.content) or {
				json2.Any(map[string]json2.Any{})
			}
			if count == 0 {
				first = parsed
			}
			last = parsed
			count++
		}
		if count == 0 {
			return praxo.response(praxo.message_assistant('', [
				praxo.tool_call('jobs-1', 'read_jobs', {
					'line': json2.Any(line)
				}),
			]), praxo.usage(0, 0))
		}
		if count == 1 {
			failure := praxo.get_string(first, 'error') or { '' }
			if failure != '' {
				return praxo.response(praxo.message_assistant(failure, []praxo.ToolCall{}),
					praxo.usage(0, 0))
			}
			return praxo.response(praxo.message_assistant('', [
				praxo.tool_call('schedule-1', 'draft_schedule', {
					'line': json2.Any(line)
					'action': json2.Any('replan')
				}),
			]), praxo.usage(0, 0))
		}
		mut report := map[string]json2.Any{}
		report['stage'] = json2.Any('schedule_drafted')
		report['jobs'] = first
		report['schedule'] = last
		report['dispatched'] = json2.Any(false)
		return praxo.response(praxo.message_assistant(praxo.encode_json(json2.Any(report)),
			[]praxo.ToolCall{}), praxo.usage(0, 0))
	})
}

fn run_case(line string, simulate_failure bool) (string, int, int, string) {
	mut state := &State{}
	mut read_tool := praxo.func_tool('read_jobs',
		'Read a fixed job queue and compute a deterministic priority order; no dispatch.')
	read_tool.invoke = fn [mut state, simulate_failure] (_arguments map[string]json2.Any) json2.Any {
		state.reads++
		if simulate_failure {
			mut failure := map[string]json2.Any{}
			failure['error'] = json2.Any('SCHEDULE_SOURCE_UNAVAILABLE')
			return json2.Any(failure)
		}
		jobs := fixture_jobs()
		mut job_values := []json2.Any{}
		for job in jobs {
			mut item := map[string]json2.Any{}
			item['id'] = json2.Any(job.id)
			item['priority'] = json2.Any(job.priority)
			item['due_min'] = json2.Any(job.due_min)
			job_values << json2.Any(item)
		}
		mut order_values := []json2.Any{}
		for id in recommended_order(jobs) {
			order_values << json2.Any(id)
		}
		mut value := map[string]json2.Any{}
		value['line'] = json2.Any('line-100')
		value['jobs'] = json2.Any(job_values)
		value['recommended_order'] = json2.Any(order_values)
		value['source'] = json2.Any('schedule_fixture')
		return json2.Any(value)
	}
	mut draft_tool := praxo.func_tool('draft_schedule',
		'Draft review-only MES/AGV instructions; never dispatches.')
	draft_tool.invoke = fn [mut state] (arguments map[string]json2.Any) json2.Any {
		state.drafts++
		mut value := map[string]json2.Any{}
		value['schedule_id'] = json2.Any('schedule-100')
		value['line'] = arguments['line'] or { json2.Any('') }
		value['action'] = arguments['action'] or { json2.Any('') }
		value['status'] = json2.Any('draft_only')
		value['review_required'] = json2.Any(true)
		value['dispatched'] = json2.Any(false)
		return json2.Any(value)
	}

	mut options := praxo.agent_options(fixture_model(line))
	options.tools = [read_tool, draft_tool]
	options.allowed_tools = ['read_jobs', 'draft_schedule']
	options.max_steps = 4
	options.require_policy = true
	options.require_tool_scope = true
	options.policy_action = fn (action praxo.Action) praxo.Decision {
		if action.kind == 'model.generate' {
			return praxo.Decision{
				allowed: true
			}
		}
		if action.kind != 'tool.invoke' {
			return praxo.Decision{
				allowed: false
				reason:  'unsupported action'
			}
		}
		line_arg := praxo.get_string(json2.Any(action.arguments), 'line') or { '' }
		if line_arg != 'line-100' {
			return praxo.Decision{
				allowed: false
				reason:  'only line-100 is in scheduling scope'
			}
		}
		if action.tool_name == 'read_jobs' {
			return praxo.Decision{
				allowed: true
			}
		}
		if action.tool_name == 'draft_schedule' {
			act := praxo.get_string(json2.Any(action.arguments), 'action') or { '' }
			return praxo.Decision{
				allowed: act == 'replan'
				reason:  'only a line-100 replan draft is allowed'
			}
		}
		return praxo.Decision{
			allowed: false
			reason:  'unsupported tool'
		}
	}
	result := praxo.run_agent(options, praxo.session('production-${line}', []praxo.Message{}),
		'Replan the fixed job queue and draft review-only instructions.') or {
		return '', state.reads, state.drafts, err.msg()
	}
	return result.output, state.reads, state.drafts, ''
}

fn main() {
	args := os.args
	if '--test' in args {
		run_tests()
		return
	}
	mut line := 'line-100'
	index := args.index('--line')
	if index >= 0 && index + 1 < args.len {
		line = args[index + 1]
	}
	output, reads, drafts, failure := run_case(line, '--simulate-failure' in args)
	if failure != '' {
		eprintln('production scheduling failed: reads=${reads} drafts=${drafts}; ${failure}')
		exit(1)
	}
	println(output)
	if output == 'SCHEDULE_SOURCE_UNAVAILABLE' {
		exit(1)
	}
}

fn run_tests() {
	success_output, success_reads, success_drafts, success_failure := run_case('line-100', false)
	if success_failure != '' || success_reads != 1 || success_drafts != 1 {
		eprintln('success failed: reads=${success_reads} drafts=${success_drafts} error=${success_failure}')
		exit(1)
	}
	report := praxo.parse_json(success_output) or {
		eprintln('success output is not JSON')
		exit(1)
	}
	stage := praxo.get_string(report, 'stage') or { '' }
	jobs := praxo.get_object(report, 'jobs')
	order := praxo.get_array(json2.Any(jobs), 'recommended_order')
	first := if order.len > 0 { praxo.as_string(order[0]) or { '' } } else { '' }
	if stage != 'schedule_drafted' || first != 'job-b'
		|| praxo.get_bool(report, 'dispatched', true) {
		eprintln('unexpected report: ${success_output}')
		exit(1)
	}
	println('success: line-100 first=job-b status=draft_only dispatched=false reads=1')

	_, denied_reads, denied_drafts, denied_failure := run_case('line-200', false)
	if !denied_failure.contains('AGENT_POLICY_DENIED') || denied_reads != 0 || denied_drafts != 0 {
		eprintln('deny failed: reads=${denied_reads} drafts=${denied_drafts} error=${denied_failure}')
		exit(1)
	}
	println('deny: AGENT_POLICY_DENIED reads=0')

	failure_output, failure_reads, failure_drafts, failure_error := run_case('line-100', true)
	if failure_error != '' || failure_output != 'SCHEDULE_SOURCE_UNAVAILABLE'
		|| failure_reads != 1 || failure_drafts != 0 {
		eprintln('failure failed: reads=${failure_reads} drafts=${failure_drafts} output=${failure_output}')
		exit(1)
	}
	println('failure: SCHEDULE_SOURCE_UNAVAILABLE reads=1')
}
