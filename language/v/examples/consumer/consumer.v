module main

import praxo
import x.json2

fn fixture_model(target string) &praxo.Model {
	return praxo.callback_model(fn [target] (request praxo.Request) !praxo.Response {
		last := request.messages[request.messages.len - 1]
		if last.role == praxo.role_tool {
			return praxo.response(praxo.message_assistant('recorded', []praxo.ToolCall{}),
				praxo.usage(0, 0))
		}
		return praxo.response(praxo.message_assistant('', [
			praxo.tool_call('record-1', 'record', {
				'target': json2.Any(target)
			}),
		]), praxo.usage(0, 0))
	})
}

fn run_case(target string) (string, int, string) {
	tool := praxo.func_tool('record', 'Record a target in an in-memory counter.')
	tool.invoke = fn (_arguments map[string]json2.Any) json2.Any {
		return json2.Any('recorded')
	}
	mut options := praxo.agent_options(fixture_model(target))
	options.tools = [tool]
	options.allowed_tools = ['record']
	options.max_steps = 3
	options.policy = fn [target] (kind string) bool {
		if kind == 'model.generate' {
			return true
		}
		if kind == 'tool.invoke' {
			return target == 'public'
		}
		return false
	}
	result := praxo.run_agent(options, praxo.session('consumer-${target}', []praxo.Message{}),
		'Record the requested target.') or { return '', tool.calls, err.msg() }
	return result.output, tool.calls, ''
}

fn main() {
	output, calls, failure := run_case('public')
	if failure != '' || output != 'recorded' || calls != 1 {
		eprintln('allow verification failed: output=${output} effects=${calls} error=${failure}')
		exit(1)
	}
	println('allow: recorded; effects=1')

	output, calls, failure = run_case('private')
	if failure == '' || !failure.contains('denied') || calls != 0 {
		eprintln('deny verification failed: output=${output} effects=${calls} error=${failure}')
		exit(1)
	}
	println('deny: policy rejected; effects=0')
}
