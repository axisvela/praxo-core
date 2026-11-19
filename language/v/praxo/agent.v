module praxo

import rand
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

fn missing_model_callback(_request Request) !Response {
	return praxo_error('MODEL_ERROR', 'model callback is not configured')
}

pub type DeltaHandler = fn (delta string)

fn noop_delta(_delta string) {}

fn missing_stream_callback(_request Request, _on_delta DeltaHandler) !Response {
	return praxo_error('MODEL_ERROR', 'model stream callback is not configured')
}

@[heap]
pub struct Model {
pub mut:
	mode            string
	script          []Response
	index           int
	content         string
	primary         &Model = unsafe { nil }
	fallback        &Model = unsafe { nil }
	callback        fn (Request) !Response = missing_model_callback
	stream_callback fn (Request, DeltaHandler) !Response = missing_stream_callback
	has_stream      bool
}

pub fn (mut model Model) generate(_request Request) !Response {
	if model.mode == 'callback' {
		return model.callback(_request)
	}
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

pub fn (mut model Model) generate_stream(request Request, on_delta DeltaHandler) !Response {
	if model.has_stream {
		return model.stream_callback(request, on_delta)
	}
	result := model.generate(request)!
	if result.message.content != '' {
		on_delta(result.message.content)
	}
	return result
}

pub fn scripted_model(steps []Response) &Model {
	return &Model{mode: 'scripted', script: steps}
}

pub fn callback_model(callback fn (Request) !Response) &Model {
	return &Model{mode: 'callback', callback: callback}
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

pub type PolicyHook = fn (kind string) bool
pub type PolicyActionHook = fn (action Action) Decision

pub const interrupt_approve = 'approve'
pub const interrupt_edit = 'edit'
pub const interrupt_reject = 'reject'
pub const interrupt_respond = 'respond'

pub struct Interrupt {
pub:
	run_id     string
	session_id string
	call       ToolCall
}

pub struct InterruptDecision {
pub:
	action    string
	arguments ?map[string]json2.Any
	response  string
	reason    string
}

pub type InterruptDecisionHandler = fn (interrupt Interrupt) InterruptDecision
pub type InterruptApproval = fn (interrupt Interrupt) bool

struct InterruptResult {
	skip     bool
	response string
	call     ToolCall
}

pub struct AgentOptions {
pub mut:
	model         &Model = unsafe { nil }
	tools         []&Tool
	tool_selection ?ToolSelection
	pii_redaction bool
	structured_output ?StructuredOutput
	model_call_limit int
	tool_call_limit int
	events        &Sink = unsafe { nil }
	system_prompt string
	max_steps     int = 8
	max_tokens    int
	session_id    string = 's1'
	policy        ?PolicyHook
	policy_action ?PolicyActionHook
	allowed_tools []string
	on_delta      DeltaHandler = noop_delta
	streaming     bool
	interrupt_on  []string
	on_interrupt_decision ?InterruptDecisionHandler
	on_interrupt  ?InterruptApproval
	require_policy bool
	require_tool_scope bool
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

fn authorize(options AgentOptions, action_value Action) ! {
	if hook := options.policy_action {
		if !hook(action_value).allowed {
			return praxo_error('AGENT_POLICY_DENIED', 'agent: ${action_value.kind} denied')
		}
		return
	}
	if hook := options.policy {
		if !hook(action_value.kind) {
			return praxo_error('AGENT_POLICY_DENIED', 'agent: ${action_value.kind} denied')
		}
	}
}

fn apply_interrupt(options AgentOptions, call ToolCall, run_id string,
	session_id string) !InterruptResult {
	if call.name !in options.interrupt_on {
		return InterruptResult{call: call}
	}
	if options.on_interrupt_decision == none && options.on_interrupt == none {
		return praxo_error('AGENT_INTERRUPT_UNHANDLED', 'agent: approval handler not configured: ${call.name}')
	}
	mut data := map[string]json2.Any{}
	data['name'] = json2.Any(call.name)
	data['arguments'] = json2.Any(call.arguments)
	emit_event(options.events, 'tool.interrupt', session_id, run_id, json2.Any(data))
	interrupt := Interrupt{run_id: run_id, session_id: session_id, call: call}
	if handler := options.on_interrupt_decision {
		interrupt_decision := handler(interrupt)
		if interrupt_decision.action == interrupt_approve {
			return InterruptResult{call: call}
		}
		if interrupt_decision.action == interrupt_edit {
			if arguments := interrupt_decision.arguments {
				return InterruptResult{call: ToolCall{...call, arguments: arguments.clone()}}
			}
			return praxo_error('AGENT_INTERRUPT_DECISION_INVALID', 'agent: edit requires arguments')
		}
		if interrupt_decision.action == interrupt_reject {
			return praxo_error('AGENT_APPROVAL_DENIED', 'agent: tool call denied by approval: ${call.name}: ${interrupt_decision.reason}')
		}
		if interrupt_decision.action == interrupt_respond {
			return InterruptResult{
				skip: true
				response: interrupt_decision.response
				call: call
			}
		}
		return praxo_error('AGENT_INTERRUPT_DECISION_INVALID', 'agent: invalid interrupt decision: ${interrupt_decision.action}')
	}
	approval := options.on_interrupt or {
		return praxo_error('AGENT_INTERRUPT_UNHANDLED', 'agent: approval handler not configured: ${call.name}')
	}
	if !approval(interrupt) {
		return praxo_error('AGENT_APPROVAL_DENIED', 'agent: tool call denied by approval: ${call.name}')
	}
	return InterruptResult{call: call}
}

fn run_agent_inner(options AgentOptions, session_value Session, run_id string,
	mut messages []Message) !RunResult {
	max_steps := if options.max_steps > 0 { options.max_steps } else { 8 }
	mut total := usage(0, 0)
	mut limit := call_limit(options.model_call_limit, options.tool_call_limit)
	for step := 1; step <= max_steps; step++ {
		mut model := options.model
		mut specs := tool_specs(options.tools)
		if options.allowed_tools.len > 0 {
			mut filtered := []ToolSpec{cap: specs.len}
			for spec in specs {
				if spec.name in options.allowed_tools {
					filtered << spec
				}
			}
			specs = filtered.clone()
		}
		if selection := options.tool_selection {
			specs = select_tools(selection, specs)
		}
		mut model_messages := messages.clone()
		if options.pii_redaction {
			model_messages = []Message{cap: messages.len}
			for msg in messages {
				mut blocks := []ContentBlock{cap: msg.content_blocks.len}
				for block in msg.content_blocks {
					blocks << ContentBlock{...block, text: pii_redact(block.text)}
				}
				mut tool_calls := []ToolCall{cap: msg.tool_calls.len}
				for call in msg.tool_calls {
					redacted := redact_value(call.arguments)
					if redacted is map[string]json2.Any {
						tool_calls << ToolCall{...call, arguments: redacted as map[string]json2.Any}
					} else {
						tool_calls << call
					}
				}
				model_messages << Message{...msg, content: pii_redact(msg.content), content_blocks: blocks, tool_calls: tool_calls}
			}
		}
		limit.model_call()!
		authorize(options, action('model.generate', session_value.id, '', map[string]json2.Any{}))!
		result := if options.streaming {
			model.generate_stream(request(model_messages, specs), options.on_delta) or {
				return err
			}
		} else {
			model.generate(request(model_messages, specs)) or {
				return err
			}
		}
		total = usage_plus(total, result.usage)
		if options.max_tokens > 0 && total.input_tokens + total.output_tokens > options.max_tokens {
			return praxo_error('AGENT_MAX_TOKENS', 'token budget exceeded')
		}
		messages << result.message
		if result.message.tool_calls.len == 0 {
			mut output := result.message.content
			if structured := options.structured_output {
				validated, code := structured.apply(output)
				if code != '' {
					return praxo_error(code, 'structured output validation failed')
				}
				output = validated
			}
			emit_event(options.events, 'run.completed', session_value.id, run_id, json2.null)
			return run_result(run_id, output, step, total)
		}
		for call in result.message.tool_calls {
			mut active := call
			if options.allowed_tools.len > 0 && active.name !in options.allowed_tools {
				return praxo_error('AGENT_TOOL_NOT_ALLOWED', 'agent: tool ${active.name} is not allowed')
			}
			authorize(options, action('tool.invoke', session_value.id, active.name, active.arguments.clone()))!
			if selection := options.tool_selection {
				check_tool_selected(selection, active.name)!
			}
			limit.tool_call()!
			interrupted := apply_interrupt(options, active, run_id, session_value.id)!
			active = interrupted.call
			if interrupted.skip {
				messages << message_tool(encode_json(json2.Any(interrupted.response)), active.id)
				continue
			}
			if active.name != call.name
				|| !json_equals(json2.Any(active.arguments), json2.Any(call.arguments)) {
				authorize(options, action('tool.invoke', session_value.id, active.name, active.arguments.clone()))!
			}
			index := find_tool_index(options.tools, active.name)
			if index < 0 {
				return praxo_error('TOOL_NOT_FOUND', 'tool not found: ${active.name}')
			}
			mut data := map[string]json2.Any{}
			data['name'] = json2.Any(active.name)
			data['arguments'] = json2.Any(active.arguments)
			emit_event(options.events, 'tool.call', session_value.id, run_id, json2.Any(data))
			mut tool := options.tools[index]
			mut value := tool.call(active.arguments)
			if options.pii_redaction {
				value = redact_value(value)
			}
			messages << message_tool(encode_json(value), active.id)
		}
	}
	return praxo_error('AGENT_MAX_STEPS', 'maximum steps exceeded')
}

pub fn run_agent(options AgentOptions, session_value Session, prompt string) !RunResult {
	if options.require_policy && options.policy == none && options.policy_action == none {
		return praxo_error('AGENT_INVALID_OPTIONS', 'agent: require policy: policy is required')
	}
	if options.require_tool_scope && options.allowed_tools.len == 0 {
		return praxo_error('AGENT_INVALID_OPTIONS', 'agent: require tool scope: allowed_tools must not be empty')
	}
	if options.model == unsafe { nil } {
		return praxo_error('MODEL_ERROR', 'model is not configured')
	}
	run_id := 'run-${time.now().unix_nano()}-${rand.u64()}'
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
