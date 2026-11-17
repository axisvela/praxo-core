#!/usr/bin/env ruby

require 'json'
require 'praxo'

M = Praxo::Models

class FakeMCPTransport
  attr_reader :effects

  def initialize
    @effects = Hash.new(0)
  end

  def request(method, params, timeout: nil)
    case method
    when 'initialize'
      {
        'protocolVersion' => '2024-11-05',
        'capabilities' => { 'tools' => {} },
        'serverInfo' => { 'name' => 'fixture-mcp', 'version' => '0.0.1' }
      }
    when 'tools/list'
      {
        'tools' => [{
          'name' => 'record',
          'description' => 'Record a target',
          'inputSchema' => {
            'type' => 'object',
            'properties' => { 'target' => { 'type' => 'string' } },
            'required' => ['target']
          }
        }]
      }
    when 'tools/call'
      call_tool(params)
    else
      raise Praxo::Error.new('MCP_RPC', "mcp: #{method} failed")
    end
  end

  def notify(_method, _params); end

  def close; end

  private

  def call_tool(params)
    name = params[:name] || params['name']
    arguments = params[:arguments] || params['arguments'] || {}
    if name != 'record'
      return { 'isError' => true, 'content' => [{ 'type' => 'text', 'text' => 'unknown tool' }] }
    end

    target = arguments['target'].to_s
    @effects[target] += 1
    { 'content' => [{ 'type' => 'text', 'text' => "recorded:#{target}" }] }
  end
end

class McpRecordTool
  attr_reader :name, :description, :parameters

  def initialize(client)
    @client = client
    @name = 'record'
    @description = 'Record a target through the MCP transport seam.'
    @parameters = {
      'type' => 'object',
      'properties' => { 'target' => { 'type' => 'string' } },
      'required' => ['target']
    }
  end

  def invoke(arguments)
    @client.call_tool('record', arguments)
  end
end

class ScriptedModel
  attr_reader :calls

  def initialize(steps, final)
    @steps = steps.dup
    @final = final
    @calls = 0
  end

  def generate(_request)
    @calls += 1
    if @steps.empty?
      M.response(message: M.message_assistant(@final))
    else
      step = @steps.shift
      M.response(message: M.message_assistant('', [step]))
    end
  end
end

class ComposedPolicy
  def initialize(*hooks)
    @hooks = hooks.compact
  end

  def call(action)
    @hooks.each do |hook|
      decision = hook.call(action)
      return decision unless decision.allowed
    end
    M.decision(allowed: true, reason: 'delegation policy chain allowed')
  end
end

PARENT_POLICY = lambda do |action|
  if action.kind == 'model.generate'
    M.decision(allowed: true, reason: 'model')
  elsif action.kind != 'tool.invoke'
    M.decision(allowed: false, reason: 'unsupported action')
  elsif action.tool_name == 'record'
    if (action.arguments || {})['target'] == 'blocked'
      M.decision(allowed: false, reason: 'blocked target')
    else
      M.decision(allowed: true, reason: 'record')
    end
  elsif action.tool_name == 'delegate'
    M.decision(allowed: true, reason: 'delegate')
  else
    M.decision(allowed: false, reason: 'parent tool is not allowed')
  end
end

CHILD_POLICY = lambda do |action|
  if action.kind == 'model.generate'
    M.decision(allowed: true, reason: 'model')
  elsif action.kind == 'tool.invoke' && action.tool_name == 'record'
    M.decision(allowed: true, reason: 'child record')
  else
    M.decision(allowed: false, reason: 'child may only record')
  end
end

def build_delegate(record, child_model, events)
  delegate = lambda do |_arguments|
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(record)
    options = Praxo::Agent::AgentOptions.new(child_model)
    options.tools = registry
    options.max_steps = 3
    options.allowed_tools = ['record']
    options.policy = ComposedPolicy.new(PARENT_POLICY, CHILD_POLICY)
    options.require_policy = true
    options.require_tool_scope = true
    options.events = events
    result = Praxo::Agent.run_agent(
      options, M.session(id: 'chain-child'), 'record child'
    )
    { 'output' => result.output }
  end
  Praxo::Agent::FuncTool.new(
    'delegate',
    'Run a governed child agent with the narrowed record scope.',
    delegate
  )
end

class EventLog
  attr_reader :otel, :harmovela

  def initialize
    @otel = []
    @harmovela = []
  end

  def sinks
    Praxo::Runtime::MultiSink.new([
      Praxo::Adapters::OtelSink.new(transport: method(:send_otel)),
      Praxo::Adapters::HarmovelaSink.new(
        base_url: 'http://harmovela.local',
        transport: method(:send_harmovela)
      )
    ])
  end

  private

  def send_otel(_endpoint, body, _headers)
    payload = JSON.parse(body)
    Array(payload['resourceSpans']).each do |resource|
      Array(resource['scopeSpans']).each do |scope|
        Array(scope['spans']).each { |span| @otel << span['name'].to_s }
      end
    end
    [200, '']
  end

  def send_harmovela(_path, body, _headers)
    payload = JSON.parse(body)
    @harmovela << payload['type'].to_s
    [202, '']
  end
end

def run_chain
  transport = FakeMCPTransport.new
  client = Praxo::Adapters::MCPClient.new(transport: transport).start
  begin
    record = McpRecordTool.new(client)
    events = EventLog.new
    child_model = ScriptedModel.new(
      [M.tool_call(id: 'child-record', name: 'record', arguments: { 'target' => 'child' })],
      'CHILD-DONE'
    )
    parent_model = ScriptedModel.new(
      [
        M.tool_call(id: 'parent-record', name: 'record', arguments: { 'target' => 'parent' }),
        M.tool_call(id: 'parent-delegate', name: 'delegate', arguments: { 'task' => 'child' })
      ],
      'DONE'
    )
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(record)
    registry.register(build_delegate(record, child_model, events.sinks))
    options = Praxo::Agent::AgentOptions.new(parent_model)
    options.tools = registry
    options.max_steps = 6
    options.allowed_tools = %w[record delegate]
    options.policy = PARENT_POLICY
    options.require_policy = true
    options.require_tool_scope = true
    options.events = events.sinks
    result = Praxo::Agent.run_agent(
      options, M.session(id: 'chain-parent'), 'run the representative chain'
    )
    {
      output: result.output,
      effects: transport.effects.dup,
      child_calls: child_model.calls,
      otel: events.otel,
      harmovela: events.harmovela
    }
  ensure
    client.close
  end
end

def run_denial
  transport = FakeMCPTransport.new
  client = Praxo::Adapters::MCPClient.new(transport: transport).start
  begin
    record = McpRecordTool.new(client)
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(record)
    model = ScriptedModel.new(
      [M.tool_call(id: 'denied-record', name: 'record', arguments: { 'target' => 'safe' })],
      'UNEXPECTED'
    )
    edit = Object.new
    def edit.before_tool(call)
      call.arguments = { 'target' => 'blocked' }
      call
    end
    options = Praxo::Agent::AgentOptions.new(model)
    options.tools = registry
    options.max_steps = 2
    options.allowed_tools = ['record']
    options.policy = PARENT_POLICY
    options.middleware = [edit]
    options.require_policy = true
    options.require_tool_scope = true
    begin
      Praxo::Agent.run_agent(options, M.session(id: 'chain-denial'), 'call record')
    rescue Praxo::Error => error
      return { blocked: transport.effects['blocked'].to_i, code: error.code }
    end
    raise 'denial path unexpectedly succeeded'
  ensure
    client.close
  end
end

def check(condition, message)
  raise message unless condition
end

result = run_chain
check(result[:output] == 'DONE', 'parent output was not DONE')
check(result[:effects]['parent'] == 1, 'parent effect count was not one')
check(result[:effects]['child'] == 1, 'child effect count was not one')
check(result[:child_calls] >= 2, 'child model calls were fewer than two')
%w[praxo.run.started praxo.tool.call praxo.run.completed].each do |span|
  check(result[:otel].include?(span), "missing otel span #{span}")
end
%w[run.started tool.call run.completed].each do |kind|
  check(result[:harmovela].include?(kind), "missing harmovela event #{kind}")
end
denial = run_denial
check(denial[:blocked].zero?, 'denied target produced an effect')
check(denial[:code] == 'AGENT_POLICY_DENIED', 'denial code was not AGENT_POLICY_DENIED')

puts "output: #{result[:output]}"
puts "effects: parent=#{result[:effects]['parent']} child=#{result[:effects]['child']}"
puts "child calls: #{result[:child_calls]}"
puts "otel spans: #{result[:otel].length}"
puts "harmovela events: #{result[:harmovela].length}"
puts "denied effects: #{denial[:blocked]}"
