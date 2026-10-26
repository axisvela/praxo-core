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

puts 'ruby core tests passed'
