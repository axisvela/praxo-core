module praxo

import time
import x.json2

pub fn echo_invoke(arguments map[string]json2.Any) json2.Any {
	return json2.Any(arguments)
}

@[heap]
pub struct Tool {
pub mut:
	name        string
	description string
	calls       int
	invoke      fn (arguments map[string]json2.Any) json2.Any = echo_invoke
}

pub fn (mut tool Tool) call(arguments map[string]json2.Any) json2.Any {
	tool.calls++
	return tool.invoke(arguments)
}

pub fn func_tool(name string, description string) &Tool {
	return &Tool{name: name, description: description}
}

@[heap]
pub struct Model {
pub mut:
	mode     string
	script   []Response
	index    int
	content  string
	primary  &Model = unsafe { nil }
	fallback &Model = unsafe { nil }
}

pub fn (mut model Model) generate(_request Request) !Response {
	if model.mode == 'fallback' {
		if model.primary != unsafe { nil } {
			return model.primary.generate(_request) or {
				if model.fallback != unsafe { nil } {
					return model.fallback.generate(_request)
				}
				return err
			}
		}
		return praxo_error('MODEL_ERROR', 'fallback model is not configured')
	}
	if model.mode == 'static' {
		return Response{message: message_assistant(model.content, []ToolCall{})}
	}
	if model.mode == 'failing' {
		return praxo_error('MODEL_ERROR', 'primary model failed')
	}
	if model.index >= model.script.len {
		return praxo_error('MODEL_ERROR', 'script exhausted')
	}
	result := model.script[model.index]
	model.index++
	return result
}

pub fn scripted_model(steps []Response) &Model {
	return &Model{mode: 'scripted', script: steps}
}

pub fn static_model(content string) &Model {
	return &Model{mode: 'static', content: content}
}

pub fn failing_model() &Model {
	return &Model{mode: 'failing'}
}

pub fn fallback_model(primary &Model, fallback &Model) &Model {
	return &Model{mode: 'fallback', primary: primary, fallback: fallback}
}

pub struct AgentOptions {
pub mut:
	model         &Model = unsafe { nil }
	tools         []&Tool
	events        &Sink = unsafe { nil }
	system_prompt string
	max_steps     int = 8
	max_tokens    int
	session_id    string = 's1'
}

pub fn agent_options(model &Model) AgentOptions {
	return AgentOptions{model: model, max_steps: 8, session_id: 's1'}
}

fn tool_specs(tools []&Tool) []ToolSpec {
	mut specs := []ToolSpec{cap: tools.len}
	for tool in tools {
		specs << tool_spec(tool.name, tool.description)
	}
	return specs
}

fn find_tool_index(tools []&Tool, name string) int {
	for index, tool in tools {
		if tool.name == name {
			return index
		}
	}
	return -1
}

fn emit_event(events &Sink, kind string, session_id string, run_id string, data json2.Any) {
	if events == unsafe { nil } {
		return
	}
	mut sink := unsafe { events }
	sink.emit(Event{kind: kind, session_id: session_id, run_id: run_id, data: data})
}

fn run_agent_inner(options AgentOptions, session_value Session, run_id string,
	mut messages []Message) !RunResult {
	max_steps := if options.max_steps > 0 { options.max_steps } else { 8 }
	mut total := usage(0, 0)
	for step := 1; step <= max_steps; step++ {
		mut model := options.model
		result := model.generate(request(messages, tool_specs(options.tools))) or {
			return err
		}
		total = usage_plus(total, result.usage)
		if options.max_tokens > 0 && total.input_tokens + total.output_tokens > options.max_tokens {
			return praxo_error('AGENT_MAX_TOKENS', 'token budget exceeded')
		}
		messages << result.message
		if result.message.tool_calls.len == 0 {
			emit_event(options.events, 'run.completed', session_value.id, run_id, json2.null)
			return run_result(run_id, result.message.content, step, total)
		}
		for call in result.message.tool_calls {
			index := find_tool_index(options.tools, call.name)
			if index < 0 {
				return praxo_error('TOOL_NOT_FOUND', 'tool not found: ${call.name}')
			}
			mut data := map[string]json2.Any{}
			data['name'] = json2.Any(call.name)
			data['arguments'] = json2.Any(call.arguments)
			emit_event(options.events, 'tool.call', session_value.id, run_id, json2.Any(data))
			mut tool := options.tools[index]
			value := tool.call(call.arguments)
			messages << message_tool(encode_json(value), call.id)
		}
	}
	return praxo_error('AGENT_MAX_STEPS', 'maximum steps exceeded')
}

pub fn run_agent(options AgentOptions, session_value Session, prompt string) !RunResult {
	if options.model == unsafe { nil } {
		return praxo_error('MODEL_ERROR', 'model is not configured')
	}
	run_id := 'run-${time.now().unix()}'
	mut messages := []Message{}
	messages << session_value.messages
	if options.system_prompt != '' {
		messages.insert(0, message(role_system, options.system_prompt))
	}
	messages << message(role_user, prompt)
	emit_event(options.events, 'run.started', session_value.id, run_id, json2.null)
	return run_agent_inner(options, session_value, run_id, mut messages) or {
		mut data := map[string]json2.Any{}
		data['error'] = json2.Any(err.msg())
		emit_event(options.events, 'run.failed', session_value.id, run_id, json2.Any(data))
		return err
	}
}
