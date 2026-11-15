module main

import praxo
import x.json2

const checkpoint_type = 'session'

pub struct Outcome {
pub:
	restored_messages int
	output            string
}

fn turn_model_generate(request praxo.Request) !praxo.Response {
	return praxo.response(
		praxo.message_assistant('turn ${request.messages.len}', []praxo.ToolCall{}),
		praxo.usage(0, 0),
	)
}

struct MemoryStore {
mut:
	records map[string]string
}

fn (mut store MemoryStore) save(session_id string, payload string) {
	store.records[session_id] = payload
}

fn (store MemoryStore) load(session_id string) !string {
	return store.records[session_id] or {
		return praxo.praxo_error('CHECKPOINT_ERROR', 'checkpoint not found')
	}
}

fn wire_messages(messages []praxo.Message) []json2.Any {
	mut items := []json2.Any{cap: messages.len}
	for item in messages {
		items << json2.Any(praxo.message_wire(item))
	}
	return items
}

fn checkpoint_payload(messages []praxo.Message) json2.Any {
	mut payload := map[string]json2.Any{}
	payload['messages'] = json2.Any(wire_messages(messages))
	return json2.Any(payload)
}

fn restore_messages(value json2.Any) []praxo.Message {
	mut messages := []praxo.Message{}
	for item in praxo.get_array(value, 'messages') {
		messages << praxo.message(
			praxo.get_string(item, 'role') or { '' },
			praxo.get_string(item, 'content') or { '' },
		)
	}
	return messages
}

pub fn run() !Outcome {
	mut allow := praxo.checkpoint_allowlist()
	allow.register(checkpoint_type)!
	mut store := MemoryStore{}
	mut messages := [
		praxo.message(praxo.role_user, 'first'),
		praxo.message(praxo.role_assistant, 'ack'),
	]
	store.save('session-1', allow.marshal(checkpoint_type, checkpoint_payload(messages))!)

	mut options := praxo.agent_options(praxo.callback_model(turn_model_generate))
	options.max_steps = 2

	loaded := allow.unmarshal(store.load('session-1')!)!
	messages = restore_messages(loaded)
	mut session_value := praxo.Session{
		id: 'session-1'
		messages: messages
	}
	second := praxo.run_agent(options, session_value, 'second')!
	if second.output != 'turn 3' {
		return praxo.praxo_error('CHECKPOINT_ERROR', 'unexpected second turn: ${second.output}')
	}

	messages << praxo.message(praxo.role_user, 'second')
	messages << praxo.message(praxo.role_assistant, second.output)
	store.save('session-1', allow.marshal(checkpoint_type, checkpoint_payload(messages))!)

	restored := allow.unmarshal(store.load('session-1')!)!
	messages = restore_messages(restored)
	session_value = praxo.Session{
		id: 'session-1'
		messages: messages
	}
	third := praxo.run_agent(options, session_value, 'third')!
	if third.output != 'turn 5' {
		return praxo.praxo_error('CHECKPOINT_ERROR', 'unexpected third turn: ${third.output}')
	}

	return Outcome{
		restored_messages: messages.len
		output: third.output
	}
}

fn main() {
	outcome := run() or {
		eprintln(err.msg())
		exit(1)
	}
	println('restored messages: ${outcome.restored_messages}')
	println('output: ${outcome.output}')
}
