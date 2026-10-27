module praxo

import x.json2

pub const role_system = 'system'
pub const role_user = 'user'
pub const role_assistant = 'assistant'
pub const role_tool = 'tool'

pub const stream_kinds = ['values', 'updates', 'messages', 'tasks', 'debug', 'checkpoint']

pub struct ContentBlock {
pub:
	kind      string
	text      string
	image_url string
	data      string
}

pub struct ToolCall {
pub:
	id        string
	name      string
	arguments map[string]json2.Any
}

pub struct Message {
pub:
	role           string
	content        string
	content_blocks []ContentBlock
	tool_calls     []ToolCall
	tool_id        string
}

pub struct ToolSpec {
pub:
	name        string
	description string
}

pub struct Usage {
pub:
	input_tokens  int
	output_tokens int
}

pub struct Request {
pub:
	messages    []Message
	tools       []ToolSpec
	tool_choice string
}

pub struct Response {
pub:
	message Message
	usage   Usage
}

pub struct Session {
pub:
	id       string
	messages []Message
}

pub struct RunResult {
pub:
	run_id string
	output string
	steps  int
	usage  Usage
}

pub struct MemoryRecord {
pub mut:
	id         string
	frame      string
	content    string
	created_at string
}

pub struct PathGrant {
pub:
	root   string
	access string
}

pub struct Decision {
pub:
	allowed bool
	reason  string
}

pub struct Action {
pub:
	kind       string
	session_id string
	tool_name  string
	arguments  map[string]json2.Any
}

pub struct ContextBudget {
pub:
	max_tokens  int
	keep_recent int
}

pub struct Event {
pub:
	kind       string
	session_id string
	run_id     string
	data       json2.Any = json2.null
}

pub fn content_block(kind string, text string) ContentBlock {
	return ContentBlock{kind: kind, text: text}
}

pub fn tool_call(id string, name string, arguments map[string]json2.Any) ToolCall {
	return ToolCall{id: id, name: name, arguments: arguments}
}

pub fn message(role string, content string) Message {
	return Message{role: role, content: content}
}

pub fn message_assistant(content string, tool_calls []ToolCall) Message {
	return Message{role: role_assistant, content: content, tool_calls: tool_calls}
}

pub fn message_tool(content string, tool_id string) Message {
	return Message{role: role_tool, content: content, tool_id: tool_id}
}

pub fn tool_spec(name string, description string) ToolSpec {
	return ToolSpec{name: name, description: description}
}

pub fn usage(input_tokens int, output_tokens int) Usage {
	return Usage{input_tokens: input_tokens, output_tokens: output_tokens}
}

pub fn usage_plus(left Usage, right Usage) Usage {
	return Usage{
		input_tokens: left.input_tokens + right.input_tokens
		output_tokens: left.output_tokens + right.output_tokens
	}
}

pub fn request(messages []Message, tools []ToolSpec) Request {
	return Request{messages: messages, tools: tools}
}

pub fn response(message Message, usage_value Usage) Response {
	return Response{message: message, usage: usage_value}
}

pub fn session(id string, messages []Message) Session {
	return Session{id: id, messages: messages}
}

pub fn run_result(run_id string, output string, steps int, usage_value Usage) RunResult {
	return RunResult{run_id: run_id, output: output, steps: steps, usage: usage_value}
}

pub fn memory_record(id string, frame string, content string, created_at string) MemoryRecord {
	return MemoryRecord{id: id, frame: frame, content: content, created_at: created_at}
}

pub fn path_grant(root string, access string) PathGrant {
	return PathGrant{root: root, access: access}
}

pub fn decision(allowed bool, reason string) Decision {
	return Decision{allowed: allowed, reason: reason}
}

pub fn action(kind string, session_id string, tool_name string, arguments map[string]json2.Any) Action {
	return Action{kind: kind, session_id: session_id, tool_name: tool_name, arguments: arguments}
}

pub fn context_budget(max_tokens int, keep_recent int) ContextBudget {
	return ContextBudget{max_tokens: max_tokens, keep_recent: keep_recent}
}

pub fn event(kind string, session_id string) Event {
	return Event{kind: kind, session_id: session_id}
}

pub fn message_wire(value Message) map[string]json2.Any {
	mut out := map[string]json2.Any{}
	out['role'] = json2.Any(value.role)
	if value.content != '' || (value.content_blocks.len == 0 && value.tool_calls.len == 0
		&& value.tool_id == '') {
		out['content'] = json2.Any(value.content)
	}
	if value.content_blocks.len > 0 {
		mut blocks := []json2.Any{cap: value.content_blocks.len}
		for block in value.content_blocks {
			mut wire := map[string]json2.Any{}
			wire['type'] = json2.Any(block.kind)
			if block.text != '' {
				wire['text'] = json2.Any(block.text)
			}
			if block.image_url != '' {
				wire['image_url'] = json2.Any(block.image_url)
			}
			if block.data != '' {
				wire['data'] = json2.Any(block.data)
			}
			blocks << json2.Any(wire)
		}
		out['contentBlocks'] = json2.Any(blocks)
	}
	if value.tool_calls.len > 0 {
		mut calls := []json2.Any{cap: value.tool_calls.len}
		for call in value.tool_calls {
			mut wire := map[string]json2.Any{}
			wire['id'] = json2.Any(call.id)
			wire['name'] = json2.Any(call.name)
			wire['arguments'] = json2.Any(call.arguments)
			calls << json2.Any(wire)
		}
		out['toolCalls'] = json2.Any(calls)
	}
	if value.tool_id != '' {
		out['toolId'] = json2.Any(value.tool_id)
	}
	return out
}
