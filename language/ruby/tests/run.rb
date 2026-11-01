#!/usr/bin/env ruby

require 'tmpdir'
require 'fileutils'
require_relative '../lib/praxo'

J = Praxo::Json
M = Praxo::Models

def check(condition, message)
  raise message unless condition
end

call = Praxo::Toolcall.parse_toolcall('{"name":"echo","input":{"text":"hi"}}')
check(!call.nil? && call.name == 'echo' && call.input['text'] == 'hi', 'toolcall')
check(Praxo::Toolcall.strip_markup(
  'hello<tool_call name="echo">{"text":"hi"}</tool_call>world'
) == 'helloworld', 'toolcall strip')

schema = J.parse('{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}')
errors = Praxo::JsonSchema.validate(schema, {})
check(errors.length == 1 && errors[0].path == '$.name', 'jsonschema')
check(Praxo::JsonSchema.validate(schema, { 'name' => 'ok' }).empty?, 'jsonschema valid')
unicode_schema = J.parse('{"type":"string","minLength":2,"maxLength":2}')
check(Praxo::JsonSchema.validate(unicode_schema, '你好').empty?, 'schema unicode two')
check(Praxo::JsonSchema.validate(unicode_schema, '你').length == 1, 'schema unicode one')
integer_schema = J.parse('{"type":"integer"}')
check(Praxo::JsonSchema.validate(integer_schema, 2).empty?, 'schema integer')
check(Praxo::JsonSchema.validate(integer_schema, 2.5).length == 1, 'schema integer fraction')

manifest = Praxo::Plugin.parse_manifest(
  '{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0",' \
  '"kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},' \
  '"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},' \
  '"health":{},"isolation":"process"}'
)
check(manifest.id == 'com.example.echo', 'plugin')

store = Praxo::Runtime::MemoryStore.new
store.put('s1', M.memory_record(id: 'm1', content: 'Alpha', created_at: '2026-01-01T00:00:00Z'))
store.put('s1', M.memory_record(id: 'm2', content: 'ALPHABET', created_at: '2026-01-02T00:00:00Z'))
check(store.search('s1', 'alpha', 10).map(&:id) == %w[m2 m1], 'memory')

allowlist = Praxo::Runtime::CheckpointAllowlist.new
allowlist.register('spec.payload')
data = allowlist.marshal('spec.payload', { 'value' => 'x' })
check(allowlist.unmarshal(data) == { 'value' => 'x' }, 'checkpoint')

Dir.mktmpdir('praxo-ruby-tests-') do |root|
  grant = File.join(root, 'root')
  FileUtils.mkdir_p(grant)
  checker = Praxo::Runtime::PathChecker.new([
    M::PathGrant.new(root: grant, access: 'readwrite')
  ])
  check(checker.check(File.join(grant, 'a.txt'), 'read').allowed, 'policy allow')
  check(!checker.check(File.join(root, 'root-evil', 'x.txt'), 'read').allowed, 'policy sibling')
end

messages = [M.message_text(M::SYSTEM, 'sys')] +
           (0...10).map { |index| M.message_text(M::USER, "message #{index}") }
check(Praxo::Runtime.estimate_tokens(messages) == 64, 'context estimate')
output, ok = Praxo::Runtime::ContextBudget.new(max_tokens: 30, keep_recent: 2).compact(messages)
check(ok, 'context compact')
check(Praxo::Runtime.estimate_tokens(output) == 25, 'context compact tokens')
check(output[1].content == '[context compacted: 8 older messages omitted]', 'context marker')

check(Praxo::Middleware.redact('email a@b.com') == 'email [REDACTED:email]', 'pii')
pii_history = {
  'messages' => [{
    'content' => 'email a@b.com',
    'toolCalls' => [{
      'arguments' => { 'email' => 'a@b.com', 'nested' => { 'ssn' => '123-45-6789' } }
    }]
  }]
}
redacted_history = Praxo::Middleware.redact_value(pii_history)
arguments = redacted_history.dig('messages', 0, 'toolCalls', 0, 'arguments')
check(arguments['email'] == '[REDACTED:email]', 'pii tool-call email')
check(arguments.dig('nested', 'ssn') == '[REDACTED:ssn]', 'pii nested tool-call ssn')
check(pii_history.dig('messages', 0, 'toolCalls', 0, 'arguments', 'email') == 'a@b.com',
      'pii input unchanged')
structured_schema = J.parse(
  '{"type":"object","properties":{"value":{"type":"integer"}},"required":["value"]}'
)
text, code = Praxo::Middleware.structured_apply(structured_schema, '{"value":1}', 0)
check(text == '{"value":1}' && code.nil?, 'structured')

limit = Praxo::Middleware::CallLimit.new(model_limit: 1, tool_limit: 0)
limit.before_model
caught = false
begin
  limit.before_model
rescue StandardError
  caught = true
end
check(caught, 'call limit')

selection = Praxo::Middleware::ToolSelection.new(['echo'])
tools = [M.tool_spec(name: 'echo'), M.tool_spec(name: 'other')]
check(selection.filter(tools).map(&:name) == ['echo'], 'tool selection')
caught = false
begin
  selection.reject('other')
rescue StandardError
  caught = true
end
check(caught, 'tool selection reject')

fallback = ->(_request) { M.response(message: M.message_assistant('fallback')) }
handler = Praxo::Middleware.fallback_model(fallback).call(->(_request) {
  Praxo.error('PRIMARY_FAILED', 'primary')
})
check(handler.call(M.request).message.content == 'fallback', 'fallback')

class TestSink
  attr_reader :types

  def initialize
    @types = []
  end

  def emit(event)
    @types << event.type
  end
end

class TestModel
  def initialize(steps)
    @steps = steps
    @next = 0
  end

  def generate(_request)
    step = @steps[@next]
    @next += 1
    calls = (step['toolCalls'] || []).map do |item|
      M.tool_call(id: item['id'], name: item['name'], arguments: item['arguments'])
    end
    M.response(message: M.message_assistant(step['content'].to_s, calls))
  end
end

invocations = 0
registry = Praxo::Agent::ToolRegistry.new
registry.register(Praxo::Agent::FuncTool.new('echo', 'Echo', ->(arguments) {
  invocations += 1
  arguments
}))
sink = TestSink.new
options = Praxo::Agent::AgentOptions.new(TestModel.new([
  { 'content' => '', 'toolCalls' => [{ 'id' => 'c1', 'name' => 'echo',
                                        'arguments' => { 'text' => 'hi' } }] },
  { 'content' => 'done' }
]))
options.tools = registry
options.events = sink
result = Praxo::Agent.run_agent(options, M.session(id: 's1'), 'go')
check(result.output == 'done' && result.steps == 2 && invocations == 1, 'agent loop')
check(sink.types == %w[run.started tool.call run.completed], 'agent events')

capacity_options = Praxo::Agent::AgentOptions.new(TestModel.new([{ 'content' => 'done' }]))
capacity_options.system_prompt = 'x' * 1000
capacity_options.context = Praxo::Runtime::ContextBudget.new(max_tokens: 10, keep_recent: 0)
caught = false
begin
  Praxo::Agent.run_agent(capacity_options, M.session(id: 's1'), 'go')
rescue StandardError
  caught = true
end
check(caught, 'capacity fail closed')


class TestMiddleware
  attr_accessor :before_run_hook, :after_run_hook, :before_tool_hook

  def before_run(state)
    @before_run_hook&.call(state)
  end

  def after_run(result, error)
    @after_run_hook&.call(result, error)
  end

  def before_tool(call)
    @before_tool_hook ? @before_tool_hook.call(call) : call
  end
end

def tool_model
  TestModel.new([
    { 'content' => '', 'toolCalls' => [{ 'id' => 'c1', 'name' => 'echo',
                                          'arguments' => { 'text' => 'hi' } }] },
    { 'content' => 'done' }
  ])
end

arguments_invoked = []
arguments_registry = Praxo::Agent::ToolRegistry.new
arguments_registry.register(Praxo::Agent::FuncTool.new('echo', 'Echo', lambda { |arguments|
  arguments_invoked << arguments
  arguments
}))
arguments_policy = []
arguments_middleware = TestMiddleware.new
arguments_middleware.before_tool_hook = lambda { |call|
  call.arguments = { 'text' => 'mutated' }
  call
}
arguments_options = Praxo::Agent::AgentOptions.new(tool_model)
arguments_options.tools = arguments_registry
arguments_options.policy = lambda { |action|
  arguments_policy << action
  M.decision(allowed: true)
}
arguments_options.middleware << arguments_middleware
arguments_result = Praxo::Agent.run_agent(arguments_options, M.session(id: 's1'), 'go')
check(arguments_result.output == 'done' && arguments_invoked.first['text'] == 'mutated',
      'ruby final arguments effect')
check(arguments_policy.count { |action| action.kind == 'tool.invoke' } == 2,
      'ruby final arguments reauthorized')

rename_invoked = []
rename_registry = Praxo::Agent::ToolRegistry.new
rename_registry.register(Praxo::Agent::FuncTool.new('echo', 'Echo', lambda { |arguments|
  arguments
}))
rename_registry.register(Praxo::Agent::FuncTool.new('other', 'Other', lambda { |arguments|
  rename_invoked << arguments
  arguments
}))
rename_middleware = TestMiddleware.new
rename_middleware.before_tool_hook = lambda { |call|
  call.name = 'other'
  call
}
rename_options = Praxo::Agent::AgentOptions.new(tool_model)
rename_options.tools = rename_registry
rename_options.middleware << rename_middleware
Praxo::Agent.run_agent(rename_options, M.session(id: 's1'), 'go')
check(rename_invoked.length == 1, 'ruby final name uses final tool')

denied_options = Praxo::Agent::AgentOptions.new(tool_model)
denied_options.tools = rename_registry
denied_options.allowed_tools = ['echo']
denied_options.middleware << rename_middleware
caught = false
begin
  Praxo::Agent.run_agent(denied_options, M.session(id: 's1'), 'go')
rescue StandardError
  caught = true
end
check(caught, 'ruby final name allowlist')

unchanged_policy = []
unchanged_options = Praxo::Agent::AgentOptions.new(tool_model)
unchanged_options.tools = arguments_registry
unchanged_options.policy = lambda { |action|
  unchanged_policy << action
  M.decision(allowed: true)
}
unchanged_options.middleware << TestMiddleware.new
Praxo::Agent.run_agent(unchanged_options, M.session(id: 's1'), 'go')
check(unchanged_policy.count { |action| action.kind == 'tool.invoke' } == 1,
      'ruby unchanged single authorization')

initial_calls = 0
initial_options = Praxo::Agent::AgentOptions.new(tool_model)
initial_options.tools = arguments_registry
initial_options.policy = lambda { |action|
  action.kind == 'tool.invoke' ? M.decision(allowed: false) : M.decision(allowed: true)
}
initial_middleware = TestMiddleware.new
initial_middleware.before_tool_hook = lambda { |call|
  initial_calls += 1
  call
}
initial_options.middleware << initial_middleware
caught = false
begin
  Praxo::Agent.run_agent(initial_options, M.session(id: 's1'), 'go')
rescue StandardError
  caught = true
end
check(caught && initial_calls.zero?, 'ruby initial denial prevents middleware')

startup_calls = []
startup_first = TestMiddleware.new
startup_first.before_run_hook = ->(_state) { startup_calls << 'first.before' }
startup_first.after_run_hook = ->(_result, _error) { startup_calls << 'first.after' }
startup_second = TestMiddleware.new
startup_second.before_run_hook = ->(_state) { raise 'startup failed' }
startup_second.after_run_hook = ->(_result, _error) { startup_calls << 'second.after' }
startup_options = Praxo::Agent::AgentOptions.new(TestModel.new([{ 'content' => 'done' }]))
startup_options.middleware = [startup_first, startup_second]
startup_sink = TestSink.new
startup_options.events = startup_sink
caught = false
begin
  Praxo::Agent.run_agent(startup_options, M.session(id: 's1'), 'go')
rescue StandardError
  caught = true
end
check(caught && startup_calls == %w[first.before first.after second.after],
      'ruby startup cleanup')
check(startup_sink.types.empty?, 'ruby startup emits no events')

continue_calls = []
continue_first = TestMiddleware.new
continue_first.after_run_hook = lambda { |_result, _error|
  continue_calls << 'first.after'
  raise 'cleanup failed'
}
continue_second = TestMiddleware.new
continue_second.after_run_hook = ->(_result, _error) { continue_calls << 'second.after' }
continue_options = Praxo::Agent::AgentOptions.new(Praxo::Agent::FuncTool.new('unused', 'unused', nil))
continue_options.middleware = [continue_first, continue_second]
continue_options.model = Object.new
continue_options.model.define_singleton_method(:generate) do |_request|
  raise 'run failed'
end
caught = false
begin
  Praxo::Agent.run_agent(continue_options, M.session(id: 's1'), 'go')
rescue StandardError => e
  caught = e.message.include?('run failed')
end
check(caught && continue_calls == %w[first.after second.after],
      'ruby after-run continues')

cleanup_calls = []
cleanup_first = TestMiddleware.new
cleanup_first.after_run_hook = lambda { |_result, _error|
  cleanup_calls << 'first.after'
  raise 'cleanup failed'
}
cleanup_second = TestMiddleware.new
cleanup_second.after_run_hook = ->(_result, _error) { cleanup_calls << 'second.after' }
cleanup_options = Praxo::Agent::AgentOptions.new(TestModel.new([{ 'content' => 'done' }]))
cleanup_options.middleware = [cleanup_first, cleanup_second]
cleanup_sink = TestSink.new
cleanup_options.events = cleanup_sink
caught = false
begin
  Praxo::Agent.run_agent(cleanup_options, M.session(id: 's1'), 'go')
rescue StandardError => e
  caught = e.message.include?('cleanup failed')
end
check(caught && cleanup_calls == %w[first.after second.after],
      'ruby cleanup fail closed')
check(cleanup_sink.types == %w[run.started run.failed], 'ruby cleanup emits failed')

puts 'ruby core tests passed'
