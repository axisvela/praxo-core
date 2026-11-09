require 'praxo'

module Starter
  M = Praxo::Models

  class FixtureModel
    def initialize(target)
      @target = target
    end

    def generate(request)
      last = request.messages.last
      if last.role == M::TOOL
        M.response(message: M.message_assistant('recorded'))
      else
        M.response(message: M.message_assistant('', [
          M.tool_call(id: 'record-1', name: 'record', arguments: { 'target' => @target })
        ]))
      end
    end
  end

  class RecordTool
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def call(_arguments)
      @calls += 1
      'recorded'
    end
  end

  def self.run_scenario(target)
    tool = RecordTool.new
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(Praxo::Agent::FuncTool.new(
      'record', 'Record a target in an in-memory counter.',
      ->(arguments) { tool.call(arguments) }
    ))
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new(target))
    options.tools = registry
    options.allowed_tools = ['record']
    options.policy = lambda do |action|
      case action.kind
      when 'model.generate'
        M.decision(allowed: true)
      when 'tool.invoke'
        M.decision(
          allowed: action.tool_name == 'record' && action.arguments['target'] == 'public',
          reason: 'only the public target is permitted'
        )
      else
        M.decision(allowed: false, reason: 'unsupported action')
      end
    end
    result = Praxo::Agent.run_agent(
      options, M.session(id: "consumer-#{target}"), 'Record the requested target.'
    )
    [result.output, tool.calls, nil]
  rescue StandardError => error
    ['', tool.calls, error]
  end

  def self.run(out = $stdout)
    output, calls, error = run_scenario('public')
    unless error.nil? && output == 'recorded' && calls == 1
      raise "allow verification failed: output=#{output.inspect} effects=#{calls} error=#{error}"
    end
    out.puts 'allow: recorded; effects=1'

    _, calls, error = run_scenario('private')
    unless error && error.message.include?('policy denied') && calls.zero?
      raise "deny verification failed: effects=#{calls} error=#{error}"
    end
    out.puts 'deny: policy rejected; effects=0'
  end
end

Starter.run if $PROGRAM_NAME == __FILE__
