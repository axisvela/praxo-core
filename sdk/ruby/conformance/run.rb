#!/usr/bin/env ruby

require 'json'
require 'tmpdir'
require 'fileutils'
require_relative '../lib/praxo'

ROOT = File.expand_path('../../..', __dir__)
J = Praxo::Json
M = Praxo::Models

def check(condition, message)
  raise message unless condition
end

def error_code(error)
  Praxo.error_code(error)
end

class RecordingSink
  attr_reader :types

  def initialize
    @types = []
  end

  def emit(event)
    @types << event.type
  end
end

class ScriptedModel
  def initialize(steps)
    @steps = steps
    @next = 0
  end

  def generate(_request)
    raise 'script exhausted' if @next >= @steps.length
    step = @steps[@next]
    @next += 1
    calls = (step['toolCalls'] || []).map do |item|
      M.tool_call(id: item['id'].to_s, name: item['name'].to_s,
                  arguments: item['arguments'] || {})
    end
    M.response(
      message: M.message_assistant(step['content'].to_s, calls),
      usage: M.usage(input_tokens: step['inputTokens'].to_i,
                     output_tokens: step['outputTokens'].to_i)
    )
  end
end

def run_toolcall(input, expect)
  operation = J.string(input, 'operation').to_s
  content = J.string(input, 'content').to_s
  if operation == 'strip'
    got = Praxo::Toolcall.strip_markup(content)
    check(got == J.string(expect, 'text').to_s, "strip: got #{got}")
    return
  end
  call = Praxo::Toolcall.parse_toolcall(content)
  if J.bool(expect, 'nil')
    check(call.nil?, 'expected nil')
    return
  end
  check(!call.nil?, 'expected a tool call')
  check(call.name == J.string(expect, 'name').to_s, "name: got #{call.name}")
  expected = J.get(expect, 'input') || {}
  check(J.equals(call.input, expected), 'input mismatch')
end

def run_jsonschema(input, expect)
  errors = Praxo::JsonSchema.validate(J.get(input, 'schema'), J.get(input, 'data'))
  paths = errors.map(&:path).sort
  expected = J.array(expect, 'errorPaths').map(&:to_s).sort
  check(errors.empty? == J.bool(expect, 'valid'), 'valid mismatch')
  check(paths == expected, 'errorPaths mismatch')
end

def run_plugin(input, expect)
  raw = J.string(input, 'raw')
  raw ||= J.stringify(J.get(input, 'manifest') || {})
  manifest = nil
  begin
    manifest = Praxo::Plugin.parse_manifest(raw)
  rescue StandardError
    manifest = nil
  end
  check(!manifest.nil? == J.bool(expect, 'valid'), 'valid mismatch')
  return if manifest.nil?
  id = J.string(expect, 'id')
  check(manifest.id == id, 'id mismatch') unless id.nil?
  kind = J.string(expect, 'kind')
  check(manifest.kind == kind, 'kind mismatch') unless kind.nil?
end

def run_memory(input, expect)
  store = Praxo::Runtime::MemoryStore.new
  J.array(input, 'puts').each do |put|
    record = J.get(put, 'record') || {}
    store.put(J.string(put, 'session').to_s, M.memory_record(
      id: J.string(record, 'id').to_s,
      frame: J.string(record, 'frame').to_s,
      content: J.string(record, 'content').to_s,
      created_at: J.string(record, 'createdAt')
    ))
  end
  records = store.search(J.string(input, 'session').to_s,
                         J.string(input, 'query').to_s, J.int(input, 'limit'))
  ids = records.empty? ? nil : records.map(&:id)
  contents = records.empty? ? nil : records.map(&:content)
  check(J.equals(ids, J.get(expect, 'ids')), 'ids mismatch')
  check(J.equals(contents, J.get(expect, 'contents')), 'contents mismatch')
end

def run_event(input, expect)
  events = J.array(input, 'events').map do |type|
    M.event(type: type.to_s, session_id: 's1')
  end
  if J.string(input, 'sink').to_s == 'multi'
    count = [J.int(input, 'sinkCount', 1), 1].max
    sinks = Array.new(count) { RecordingSink.new }
    multi = Praxo::Runtime::MultiSink.new(sinks)
    events.each { |event| multi.emit(event) }
    check(J.equals(sinks.map(&:types), J.get(expect, 'perSink')), 'perSink mismatch')
    return
  end
  sink = RecordingSink.new
  predicate = J.get(input, 'predicateTypes')
  allowed = predicate.nil? ? nil : predicate.map(&:to_s).to_h { |type| [type, true] }
  filter = Praxo::Runtime::FilterSink.new(sink, lambda do |event|
    allowed.nil? || allowed[event.type]
  end)
  events.each { |event| filter.emit(event) }
  delivered = sink.types.empty? ? nil : sink.types
  check(J.equals(delivered, J.get(expect, 'delivered')), 'delivered mismatch')
end

def run_stream(expect)
  check(J.equals(M::STREAM_KINDS, J.get(expect, 'kinds')), 'kinds mismatch')
end

def run_checkpoint(input, expect)
  allowlist = Praxo::Runtime::CheckpointAllowlist.new
  J.array(input, 'registered').each { |type| allowlist.register(type.to_s) }
  operation = J.string(input, 'operation').to_s
  operation = 'roundtrip' if operation.empty?
  type = J.string(input, 'type').to_s
  value = J.get(input, 'value')
  if operation == 'roundtrip'
    data = allowlist.marshal(type, value)
    check(J.equals(allowlist.unmarshal(data), J.get(expect, 'value')), 'value mismatch')
    return
  end
  code = ''
  begin
    if operation == 'marshal'
      allowlist.marshal(type, value)
    elsif operation == 'unmarshal'
      allowlist.unmarshal(J.stringify({ 'type' => type, 'data' => value }))
    else
      Praxo.error('CHECKPOINT_ERROR', 'unknown operation')
    end
  rescue StandardError => e
    code = error_code(e)
  end
  check(code == J.string(expect, 'errorCode').to_s, "errorCode: got #{code}")
end

def run_policy(input, expect)
  Dir.mktmpdir('praxo-policy-') do |root|
    J.array(input, 'makeDirs').each do |dir|
      FileUtils.mkdir_p(File.join(root, dir.to_s))
    end
    grants = J.array(input, 'grants').map do |item|
      grant_root = File.join(root, J.string(item, 'root').to_s)
      FileUtils.mkdir_p(grant_root)
      M::PathGrant.new(root: grant_root,
                       access: J.string(item, 'access').to_s.empty? ? 'read' : J.string(item, 'access'))
    end
    checker = Praxo::Runtime::PathChecker.new(grants)
    target = File.join(root, J.string(input, 'target').to_s)
    need = J.string(input, 'need').to_s
    need = 'read' if need.empty?
    if J.bool(expect, 'error')
      caught = false
      begin
        checker.check(target, need)
      rescue StandardError
        caught = true
      end
      check(caught, 'expected a policy error')
      return
    end
    allowed = checker.check(target, need).allowed
    check(allowed == J.bool(expect, 'allowed'), 'allowed mismatch')
  end
end

def run_context(input, expect)
  messages = J.array(input, 'messages').map do |item|
    M.message_text(J.string(item, 'role').to_s, J.string(item, 'content'))
  end
  if J.string(input, 'operation').to_s == 'estimate'
    tokens = Praxo::Runtime.estimate_tokens(messages)
    check(tokens == J.int(expect, 'tokens'), "tokens: got #{tokens}")
    return
  end
  budget = J.get(input, 'budget') || {}
  context = Praxo::Runtime::ContextBudget.new(
    max_tokens: J.int(budget, 'maxTokens'),
    keep_recent: J.int(budget, 'keepRecent')
  )
  output, ok = context.compact(messages)
  check(ok == J.bool(expect, 'ok'), 'ok mismatch')
  return unless ok
  tokens = Praxo::Runtime.estimate_tokens(output)
  check(tokens == J.int(expect, 'tokens'), "tokens: got #{tokens}")
  wire = output.map { |message| M.message_wire(message) }
  check(J.equals(wire, J.get(expect, 'messages')), 'messages mismatch')
end

def run_middleware(input, expect)
  operation = J.string(input, 'operation').to_s
  case operation
  when 'pii'
    got = Praxo::Middleware.redact(J.string(input, 'text').to_s)
    check(got == J.string(expect, 'text').to_s, 'text mismatch')
  when 'pii-value'
    got = Praxo::Middleware.redact_value(J.get(input, 'value'))
    check(J.equals(got, J.get(expect, 'value')), 'value mismatch')
  when 'structured'
    repair = J.string(input, 'repairOutput')
    output, code = Praxo::Middleware.structured_apply(
      J.get(input, 'schema') || {}, J.string(input, 'output').to_s,
      J.int(input, 'maxRepairs'), repair.nil? ? nil : ->(_text) { repair }
    )
    if J.bool(expect, 'ok')
      check(output == J.string(expect, 'output').to_s, 'output mismatch')
    else
      check(code == J.string(expect, 'errorCode').to_s, 'errorCode mismatch')
    end
  when 'call-limit'
    limit = Praxo::Middleware::CallLimit.new(
      model_limit: J.int(input, 'modelLimit'), tool_limit: J.int(input, 'toolLimit')
    )
    outcomes = J.array(input, 'calls').map do |call|
      begin
        call.to_s == 'model' ? limit.before_model : limit.before_tool
        'ok'
      rescue StandardError => e
        error_code(e)
      end
    end
    check(J.equals(outcomes, J.get(expect, 'outcomes')), 'outcomes mismatch')
  when 'tool-selection'
    selection = Praxo::Middleware::ToolSelection.new(J.array(input, 'selected').map(&:to_s))
    tools = J.array(input, 'tools').map { |name| M.tool_spec(name: name.to_s) }
    advertised = selection.filter(tools).map(&:name)
    check(J.equals(advertised, J.get(expect, 'advertised')), 'advertised mismatch')
    reject = 'ok'
    begin
      selection.reject(J.string(input, 'requested').to_s)
    rescue StandardError => e
      reject = error_code(e)
    end
    check(reject == J.string(expect, 'reject').to_s, 'reject mismatch')
  when 'fallback'
    content = J.string(input, 'fallbackContent').to_s
    fallback = ->(_request) { M.response(message: M.message_assistant(content)) }
    next_handler = ->(_request) { Praxo.error('PRIMARY_FAILED', 'primary') }
    handler = Praxo::Middleware.fallback_model(fallback).call(next_handler)
    check(handler.call(M.request).message.content.to_s == content, 'output mismatch')
  else
    raise "unknown middleware operation #{operation}"
  end
end

def run_agent_loop(input, expect)
  invocations = 0
  registry = Praxo::Agent::ToolRegistry.new
  J.array(input, 'tools').each do |item|
    registry.register(Praxo::Agent::FuncTool.new(
      J.string(item, 'name').to_s, J.string(item, 'description').to_s,
      ->(arguments) { invocations += 1; arguments }
    ))
  end
  sink = RecordingSink.new
  options = Praxo::Agent::AgentOptions.new(ScriptedModel.new(J.get(input, 'script') || []))
  options.tools = registry
  options.events = sink
  options.max_steps = J.int(input, 'maxSteps')
  options.max_tokens = J.int(input, 'maxTokens')
  result = nil
  failure = nil
  begin
    result = Praxo::Agent.run_agent(options, M.session(id: 's1'), J.string(input, 'prompt').to_s)
  rescue StandardError => e
    failure = e
  end
  if J.bool(expect, 'error')
    check(!failure.nil?, 'unexpected success')
    unless J.string(expect, 'errorCode').nil?
      check(error_code(failure) == J.string(expect, 'errorCode'), 'errorCode mismatch')
    end
  else
    check(failure.nil?, "unexpected failure: #{failure}")
    check(result.output == J.string(expect, 'output').to_s, 'output mismatch')
    check(result.steps == J.int(expect, 'steps'), 'steps mismatch')
  end
  check(invocations == J.int(expect, 'toolInvocations'), 'tool invocations mismatch')
  events = sink.types.empty? ? nil : sink.types
  check(J.equals(events, J.get(expect, 'events')), 'events mismatch')
end

def run_vector(group, vector)
  input = J.get(vector, 'input') || {}
  expect = J.get(vector, 'expect') || {}
  case group
  when 'toolcall' then run_toolcall(input, expect)
  when 'jsonschema' then run_jsonschema(input, expect)
  when 'plugin' then run_plugin(input, expect)
  when 'memory' then run_memory(input, expect)
  when 'event' then run_event(input, expect)
  when 'stream' then run_stream(expect)
  when 'checkpoint' then run_checkpoint(input, expect)
  when 'policy' then run_policy(input, expect)
  when 'context' then run_context(input, expect)
  when 'middleware' then run_middleware(input, expect)
  when 'agent-loop' then run_agent_loop(input, expect)
  else raise "no runner for group #{group}"
  end
end

failures = []
seen = {}
version = File.read(File.join(ROOT, 'spec', 'SPEC_VERSION')).strip
Dir.glob(File.join(ROOT, 'spec', 'vectors', '*.json')).sort.each do |path|
  name = File.basename(path, '.json')
  begin
    file = J.parse(File.read(path))
  rescue StandardError => e
    failures << "#{name}: invalid vector file: #{e.message}"
    next
  end
  group = J.string(file, 'group').to_s
  failures << "#{name}: specVersion mismatch" unless J.string(file, 'specVersion') == version
  failures << "#{name}: group mismatch" unless name == group
  J.array(file, 'vectors').each do |vector|
    id = J.string(vector, 'id').to_s
    if seen.key?(id)
      failures << "#{group}/#{id}: duplicate id with #{seen[id]}"
    end
    seen[id] = group
    begin
      run_vector(group, vector)
    rescue StandardError => e
      failures << "#{group}/#{id}: #{e.message}"
    end
  end
end

if failures.empty?
  puts 'all spec vectors passed'
  exit 0
end
warn failures.join("\n")
exit 1
