#!/usr/bin/env ruby

require 'tmpdir'
require 'fileutils'
require 'timeout'
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

sse_complete = Praxo::SSE.parse(
  "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n" \
  "data: [DONE]\n\n"
)
check(sse_complete == 'hi', 'sse complete')
caught = false
begin
  Praxo::SSE.parse("data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n")
rescue Praxo::Error => e
  caught = e.code == 'MODEL_STREAM'
end
check(caught, 'sse truncated')
caught = false
begin
  Praxo::SSE.parse("data: {\"choices\"\n\n")
rescue Praxo::Error => e
  caught = e.code == 'MODEL_STREAM'
end
check(caught, 'sse half packet')

isolation = Praxo::Middleware::CallLimit.new(model_limit: 1, tool_limit: 0)
isolation.before_model('a')
caught = false
begin
  isolation.before_model('a')
rescue StandardError => e
  caught = e.code == 'AGENT_MODEL_CALL_LIMIT'
end
check(caught, 'call limit run a')
isolation.before_model('b')
check(true, 'call limit isolated run')

cancel_flag = { value: false }
cancel_model = Object.new
cancel_model.define_singleton_method(:generate) do |_request|
  cancel_flag[:value] = true
  M.response(message: M.message_assistant('done'))
end
cancel_after = []
cancel_middleware = TestMiddleware.new
cancel_middleware.after_run_hook = lambda { |_result, error|
  cancel_after << Praxo.error_code(error)
}
cancel_options = Praxo::Agent::AgentOptions.new(cancel_model)
cancel_options.cancellation = -> { cancel_flag[:value] }
cancel_options.middleware = [cancel_middleware]
cancel_sink = TestSink.new
cancel_options.events = cancel_sink
caught = false
begin
  Praxo::Agent.run_agent(cancel_options, M.session(id: 's1'), 'go')
rescue Praxo::Error => e
  caught = e.code == 'AGENT_CANCELLED'
end
check(caught && cancel_after == ['AGENT_CANCELLED'], 'ruby model cancellation cleanup')
check(cancel_sink.types == %w[run.started run.failed], 'ruby model cancellation events')

tool_cancel_flag = { value: false }
tool_cancel_tool = Praxo::Agent::FuncTool.new('wait', 'wait', lambda { |_args|
  tool_cancel_flag[:value] = true
  'ok'
})
tool_cancel_tools = Praxo::Agent::ToolRegistry.new
tool_cancel_tools.register(tool_cancel_tool)
tool_cancel_model = Object.new
tool_cancel_model.define_singleton_method(:generate) do |request|
  if request.messages.any? { |item| item.role == M::TOOL }
    M.response(message: M.message_assistant('done'))
  else
    M.response(message: M.message(
      role: M::ASSISTANT,
      content: '',
      tool_calls: [M.tool_call(id: 'c1', name: 'wait', arguments: {})]
    ))
  end
end
tool_cancel_after = []
tool_cancel_middleware = TestMiddleware.new
tool_cancel_middleware.after_run_hook = lambda { |_result, error|
  tool_cancel_after << Praxo.error_code(error)
}
tool_cancel_options = Praxo::Agent::AgentOptions.new(tool_cancel_model)
tool_cancel_options.tools = tool_cancel_tools
tool_cancel_options.cancellation = -> { tool_cancel_flag[:value] }
tool_cancel_options.middleware = [tool_cancel_middleware]
tool_cancel_sink = TestSink.new
tool_cancel_options.events = tool_cancel_sink
caught = false
begin
  Praxo::Agent.run_agent(tool_cancel_options, M.session(id: 's1'), 'go')
rescue Praxo::Error => e
  caught = e.code == 'AGENT_CANCELLED'
end
check(caught && tool_cancel_after == ['AGENT_CANCELLED'], 'ruby tool cancellation cleanup')
check(tool_cancel_sink.types == %w[run.started tool.call run.failed],
      'ruby tool cancellation events')

stream_parts = []
stream_after = []
stream_middleware = TestMiddleware.new
stream_middleware.after_run_hook = lambda { |_result, _error|
  stream_after << true
}
stream_options = Praxo::Agent::AgentOptions.new(TestModel.new([{ 'content' => 'done' }]))
stream_options.on_stream = lambda { |part|
  stream_parts << part.kind
  raise 'stream failed' if part.kind == 'messages'
}
stream_options.middleware = [stream_middleware]
stream_sink = TestSink.new
stream_options.events = stream_sink
caught = false
begin
  Praxo::Agent.run_agent(stream_options, M.session(id: 's1'), 'go')
rescue StandardError => e
  caught = e.message.include?('stream failed')
end
check(caught && stream_parts == %w[values messages], 'ruby stream failure aborts run')
check(stream_sink.types == %w[run.started run.failed], 'ruby stream failure events')
check(stream_after.length == 1, 'ruby stream failure cleanup')

started = Queue.new
release = Queue.new
parallel_a = Praxo::Agent::FuncTool.new('a', 'a', lambda { |_args|
  started << 'a'
  release.pop
  'a'
})
parallel_b = Praxo::Agent::FuncTool.new('b', 'b', lambda { |_args|
  started << 'b'
  release.pop
  'b'
})
parallel_registry = Praxo::Agent::ToolRegistry.new
parallel_registry.register(parallel_a)
parallel_registry.register(parallel_b)
parallel_requests = []
parallel_model = Object.new
parallel_model.define_singleton_method(:generate) do |request|
  parallel_requests << request
  if request.messages.any? { |item| item.role == M::TOOL }
    M.response(message: M.message_assistant('done'))
  else
    M.response(message: M.message(
      role: M::ASSISTANT,
      content: '',
      tool_calls: [
        M.tool_call(id: 'c1', name: 'a', arguments: {}),
        M.tool_call(id: 'c2', name: 'b', arguments: {})
      ]
    ))
  end
end
parallel_options = Praxo::Agent::AgentOptions.new(parallel_model)
parallel_options.tools = parallel_registry
parallel_options.max_parallel_tools = 2
parallel_run = Thread.new do
  Praxo::Agent.run_agent(parallel_options, M.session(id: 's1'), 'go')
end
begin
  Timeout.timeout(3) do
    first = started.pop
    second = started.pop
    check([first, second].sort == %w[a b], 'parallel tools start together')
  end
rescue Timeout::Error
  parallel_run.kill
  raise 'parallel tools did not start together'
ensure
  release << true
  release << true
end
parallel_result = parallel_run.value
check(parallel_result.output == 'done', 'parallel tools result')
tool_messages = parallel_requests.last.messages.select { |item| item.role == M::TOOL }
check(tool_messages.map(&:tool_id) == %w[c1 c2], 'parallel tools preserve result order')

hitl_invocations = 0
hitl_registry = Praxo::Agent::ToolRegistry.new
hitl_registry.register(Praxo::Agent::FuncTool.new('echo', 'Echo', lambda { |arguments|
  hitl_invocations += 1
  arguments
}))
hitl_model = TestModel.new([
  { 'content' => '', 'toolCalls' => [{ 'id' => 'c1', 'name' => 'echo',
                                       'arguments' => { 'value' => 'original' } }] },
  { 'content' => 'done' }
])
hitl_options = Praxo::Agent::AgentOptions.new(hitl_model)
hitl_options.tools = hitl_registry
hitl_options.interrupt_on = ['echo']
hitl_options.on_interrupt_decision = lambda { |_interrupt|
  M.interrupt_decision(action: Praxo::Agent::INTERRUPT_APPROVE)
}
hitl_result = Praxo::Agent.run_agent(hitl_options, M.session(id: 's1'), 'go')
check(hitl_result.output == 'done' && hitl_invocations == 1,
      'ruby hitl approve')

hitl_invocations = 0
hitl_actions = []
hitl_options = Praxo::Agent::AgentOptions.new(TestModel.new([
  { 'content' => '', 'toolCalls' => [{ 'id' => 'c1', 'name' => 'echo',
                                       'arguments' => { 'value' => 'original' } }] },
  { 'content' => 'done' }
]))
hitl_options.tools = hitl_registry
hitl_options.interrupt_on = ['echo']
hitl_options.policy = lambda { |action|
  hitl_actions << action if action.kind == 'tool.invoke'
  M::Decision.new(allowed: true, reason: '')
}
hitl_options.on_interrupt_decision = lambda { |_interrupt|
  M.interrupt_decision(action: Praxo::Agent::INTERRUPT_EDIT,
                       arguments: { 'value' => 'edited' })
}
Praxo::Agent.run_agent(hitl_options, M.session(id: 's1'), 'go')
check(hitl_invocations == 1 && hitl_actions.length == 2,
      'ruby hitl edit reauthorizes')

hitl_invocations = 0
hitl_options = Praxo::Agent::AgentOptions.new(TestModel.new([
  { 'content' => '', 'toolCalls' => [{ 'id' => 'c1', 'name' => 'echo',
                                       'arguments' => { 'value' => 'original' } }] }
]))
hitl_options.tools = hitl_registry
hitl_options.interrupt_on = ['echo']
hitl_options.on_interrupt_decision = lambda { |_interrupt|
  M.interrupt_decision(action: Praxo::Agent::INTERRUPT_REJECT, reason: 'no')
}
hitl_error = nil
begin
  Praxo::Agent.run_agent(hitl_options, M.session(id: 's1'), 'go')
rescue Praxo::Error => caught
  hitl_error = caught
end
check(hitl_error&.code == 'AGENT_APPROVAL_DENIED' && hitl_invocations.zero?,
      'ruby hitl reject')

hitl_options = Praxo::Agent::AgentOptions.new(TestModel.new([
  { 'content' => '', 'toolCalls' => [{ 'id' => 'c1', 'name' => 'echo',
                                       'arguments' => { 'value' => 'original' } }] }
]))
hitl_options.tools = hitl_registry
hitl_options.interrupt_on = ['echo']
hitl_error = nil
begin
  Praxo::Agent.run_agent(hitl_options, M.session(id: 's1'), 'go')
rescue Praxo::Error => caught
  hitl_error = caught
end
check(hitl_error&.code == 'AGENT_INTERRUPT_UNHANDLED', 'ruby hitl unhandled')

hitl_sink = TestSink.new
hitl_options = Praxo::Agent::AgentOptions.new(TestModel.new([
  { 'content' => '', 'toolCalls' => [{ 'id' => 'c1', 'name' => 'echo',
                                       'arguments' => { 'value' => 'original' } }] },
  { 'content' => 'done' }
]))
hitl_options.tools = hitl_registry
hitl_options.events = hitl_sink
hitl_options.interrupt_on = ['echo']
hitl_options.on_interrupt_decision = lambda { |_interrupt|
  M.interrupt_decision(action: Praxo::Agent::INTERRUPT_APPROVE)
}
Praxo::Agent.run_agent(hitl_options, M.session(id: 's1'), 'go')
check(hitl_sink.types.count('tool.interrupt') == 1, 'ruby hitl event')


adapter_payload = nil
adapter = Praxo::Adapters::OpenAICompatible.new(
  base_url: 'http://example.test/v1',
  model: 'test-model',
  transport: lambda do |path, payload|
    check(path == '/chat/completions', 'adapter path')
    check(payload[:model] == 'test-model', 'adapter model')
    check(payload[:messages].last[:role] == 'user', 'adapter message role')
    check(payload[:tools].first[:function][:name] == 'echo', 'adapter tool')
    adapter_payload = payload
    {
      'choices' => [{
        'message' => {
          'content' => 'hello',
          'tool_calls' => [{
            'id' => 'c1',
            'function' => { 'name' => 'echo', 'arguments' => '{"text":"hi"}' }
          }]
        },
        'finish_reason' => 'tool_calls'
      }],
      'usage' => { 'prompt_tokens' => 3, 'completion_tokens' => 2 }
    }
  end
)
adapter_request = M.request(
  messages: [M.message_text(M::USER, 'hi')],
  tools: [M.tool_spec(name: 'echo', description: 'echo', parameters: { 'type' => 'object' })]
)
adapter_response = adapter.generate(adapter_request)
check(adapter_response.message.content == 'hello', 'adapter content')
check(adapter_response.message.tool_calls.first.name == 'echo', 'adapter tool name')
check(adapter_response.message.tool_calls.first.arguments['text'] == 'hi', 'adapter args')
check(adapter_response.usage.input_tokens == 3 && adapter_response.usage.output_tokens == 2, 'adapter usage')
check(adapter_response.finish_reason == 'tool_calls', 'adapter finish')

captured = nil
adapter_tool = Praxo::Adapters::OpenAICompatible.new(
  base_url: 'http://example.test/v1',
  model: 'test-model',
  transport: lambda do |_path, payload|
    captured = payload
    { 'choices' => [{ 'message' => { 'content' => 'ok' } }] }
  end
)
adapter_tool.generate(M.request(messages: [
  M.message_assistant('', [M.tool_call(id: 'c1', name: 'echo', arguments: { 'text' => 'hi' })]),
  M.message_tool('result', 'c1')
]))
check(captured[:messages][0][:tool_calls][0][:id] == 'c1', 'adapter assistant tool call')
check(captured[:messages][0][:tool_calls][0][:function][:arguments] == '{"text":"hi"}', 'adapter tool arguments')
check(captured[:messages][1][:tool_call_id] == 'c1', 'adapter tool id')

harmovela_fixed = Time.at(1_700_000_000, 123_456_789, :nsec).utc
harmovela_calls = []
harmovela = Praxo::Adapters::HarmovelaSink.new(
  base_url: 'http://example.test/aep/api/',
  clock: -> { harmovela_fixed },
  transport: lambda do |path, body, headers|
    harmovela_calls << [path, body, headers]
    [200, '']
  end
)
harmovela_event = M.event(
  type: 'tool.call', session_id: 's1', run_id: 'run-123', data: { 'name' => 'echo' }
)
check(harmovela.emit(harmovela_event).nil?, 'harmovela success')
harmovela_path, harmovela_body, harmovela_headers = harmovela_calls.first
check(harmovela_path == '/events', 'harmovela path')
check(harmovela_headers['content-type'] == 'application/json', 'harmovela content type')
harmovela_envelope = J.parse(harmovela_body)
check(harmovela_envelope['spec_version'] == '0.2', 'harmovela spec version')
check(harmovela_envelope['id'] == 'run-123-1700000000123456789', 'harmovela id')
check(harmovela_envelope['type'] == 'tool.call', 'harmovela type')
check(harmovela_envelope['source'] == 'praxo-core', 'harmovela source')
check(harmovela_envelope['created_at'] == '2023-11-14T22:13:20.123456789Z', 'harmovela created at')
check(
  harmovela_envelope['payload'] ==
    { 'name' => 'echo', 'session_id' => 's1', 'run_id' => 'run-123' },
  'harmovela payload'
)

harmovela_failed = Praxo::Adapters::HarmovelaSink.new(
  base_url: 'http://example.test/aep/api',
  clock: -> { harmovela_fixed },
  transport: ->(_path, _body, _headers) { [500, 'boom'] }
)
harmovela_error = nil
begin
  harmovela_failed.emit(harmovela_event)
rescue Praxo::Error => caught
  harmovela_error = caught
end
check(harmovela_error&.code == 'HARMOVELA_HTTP', 'harmovela non-2xx code')
check(
  harmovela_error&.message&.include?('500') && harmovela_error&.message&.include?('boom'),
  'harmovela non-2xx body'
)

anthropic_payload = nil
anthropic = Praxo::Adapters::Anthropic.new(
  model: 'claude-test',
  api_key: 'ak',
  transport: lambda do |path, payload|
    check(path == '/v1/messages', 'anthropic path')
    anthropic_payload = payload
    {
      'content' => [
        { 'type' => 'text', 'text' => 'hello' },
        { 'type' => 'tool_use', 'id' => 'tool-1', 'name' => 'echo', 'input' => { 'text' => 'hi' } }
      ],
      'stop_reason' => 'end_turn',
      'usage' => { 'input_tokens' => 3, 'output_tokens' => 4, 'cache_read_input_tokens' => 2 }
    }
  end
)
anthropic_response = anthropic.generate(M.request(
  messages: [M.message_text(M::SYSTEM, 'be brief'), M.message_text(M::USER, 'hi')],
  tools: [M.tool_spec(name: 'echo', description: 'Echo', parameters: { 'type' => 'object' })]
))
check(anthropic_response.message.content == 'hello', 'anthropic content')
check(anthropic_response.message.tool_calls.first.id == 'tool-1', 'anthropic call id')
check(anthropic_response.message.tool_calls.first.arguments['text'] == 'hi', 'anthropic args')
check(anthropic_response.usage.cached_tokens == 2, 'anthropic cached')
check(anthropic_payload[:system] == 'be brief', 'anthropic system')
check(anthropic_payload[:tools].first[:input_schema]['type'] == 'object', 'anthropic tools')

gemini_payload = nil
gemini = Praxo::Adapters::Gemini.new(
  model: 'gemini-test',
  api_key: 'gk',
  transport: lambda do |path, payload|
    check(path.end_with?(':generateContent'), 'gemini path')
    gemini_payload = payload
    {
      'candidates' => [{
        'content' => { 'parts' => [
          { 'text' => 'hello' },
          { 'functionCall' => { 'name' => 'echo', 'args' => { 'text' => 'hi' } } }
        ] },
        'finishReason' => 'STOP'
      }],
      'usageMetadata' => { 'promptTokenCount' => 3, 'candidatesTokenCount' => 4 }
    }
  end
)
gemini_response = gemini.generate(M.request(
  messages: [M.message_text(M::SYSTEM, 'be brief'), M.message_text(M::USER, 'hi')],
  tools: [M.tool_spec(name: 'echo', description: 'Echo', parameters: { 'type' => 'object' })]
))
check(gemini_response.message.content == 'hello', 'gemini content')
check(gemini_response.message.tool_calls.first.name == 'echo', 'gemini call name')
check(gemini_response.usage.input_tokens == 3, 'gemini usage')
check(gemini_payload[:system_instruction][:parts].first[:text] == 'be brief', 'gemini system')
check(gemini_payload[:toolConfig][:functionCallingConfig][:mode] == 'AUTO', 'gemini tool mode')

client_to_server_r, client_to_server_w = IO.pipe
server_to_client_r, server_to_client_w = IO.pipe
mcp_thread = Thread.new do
  while (line = client_to_server_r.gets)
    message = JSON.parse(line)
    next if message['method'] == 'notifications/initialized' ||
            message['method'] == 'notifications/cancelled'

    response = case message['method']
               when 'initialize'
                 { 'protocolVersion' => '2024-11-05', 'serverInfo' => { 'name' => 'fake' } }
               when 'tools/list'
                 if message.dig('params', 'cursor')
                   { 'tools' => [{ 'name' => 'echo', 'inputSchema' => { 'type' => 'object' } }] }
                 else
                   {
                     'tools' => [{ 'name' => 'add', 'inputSchema' => { 'type' => 'object' } }],
                     'nextCursor' => 'next'
                   }
                 end
               when 'tools/call'
                 case message.dig('params', 'name')
                 when 'echo'
                   { 'structuredContent' => { 'ok' => true } }
                 when 'text'
                   { 'content' => [{ 'type' => 'text', 'text' => 'hello' }] }
                 when 'fail'
                   { 'isError' => true }
                 else
                   next
                 end
               end
    server_to_client_w.puts(JSON.generate(
      'jsonrpc' => '2.0', 'id' => message['id'], 'result' => response
    ))
    server_to_client_w.flush
  end
rescue IOError, EOFError
  nil
end

mcp = Praxo::Adapters::MCPClient.new(
  reader: server_to_client_r,
  writer: client_to_server_w,
  timeout: 0.5
)
mcp.start
check(mcp.protocol_version == '2024-11-05', 'mcp protocol version')
check(mcp.server_info['name'] == 'fake', 'mcp server info')
tools = mcp.list_tools
check(tools.map { |tool| tool['name'] } == %w[add echo], 'mcp paginated tools')
check(mcp.call_tool('echo', { 'text' => 'hi' }) == { 'ok' => true }, 'mcp structured tool')
check(mcp.call_tool('text') == 'hello', 'mcp text tool')
mcp_error = nil
begin
  mcp.call_tool('fail')
rescue Praxo::Error => caught
  mcp_error = caught
end
check(mcp_error&.code == 'MCP_TOOL_ERROR', 'mcp tool error')
timeout_error = nil
begin
  mcp.call_tool('hang', timeout: 0.05)
rescue Praxo::Error => caught
  timeout_error = caught
end
check(timeout_error&.code == 'MCP_TIMEOUT', 'mcp timeout')
mcp.close
check(mcp.instance_variable_get(:@closed), 'mcp closed')
mcp_thread.join(2)

puts 'ruby core tests passed'
