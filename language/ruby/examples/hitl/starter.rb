$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
require 'praxo'

module HitlStarter
  M = Praxo::Models

  class FixtureModel
    def generate(request)
      last = request.messages.last
      if last.role == M::TOOL
        M.response(message: M.message_assistant('done'))
      else
        M.response(message: M.message_assistant('', [
          M.tool_call(id: 'write-note-1', name: 'write_note',
                      arguments: { 'text' => 'hello', 'visibility' => 'public' })
        ]))
      end
    end
  end

  class WriteNoteTool
    attr_reader :notes

    def initialize
      @notes = []
    end

    def name = 'write_note'
    def description = 'Write a short note with the requested visibility.'
    def risk = 'write'
    def parameters = {
      'type' => 'object',
      'required' => ['text', 'visibility'],
      'properties' => {
        'text' => { 'type' => 'string' },
        'visibility' => { 'type' => 'string', 'enum' => ['public', 'private'] }
      }
    }

    def invoke(arguments)
      @notes << arguments['text']
      'written'
    end
  end

  def self.policy(action)
    case action.kind
    when 'model.generate'
      M.decision(allowed: true)
    when 'tool.invoke'
      M.decision(
        allowed: action.tool_name == 'write_note' &&
          action.arguments['visibility'] == 'public',
        reason: 'only public notes are permitted'
      )
    else
      M.decision(allowed: false, reason: 'unsupported action')
    end
  end

  def self.run_scenario(decision)
    tool = WriteNoteTool.new
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(tool)
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new)
    options.tools = registry
    options.max_steps = 3
    options.allowed_tools = ['write_note']
    options.policy = ->(action) { policy(action) }
    options.interrupt_on = ['write_note']
    options.on_interrupt_decision = ->(_interrupt) { decision }
    result = Praxo::Agent.run_agent(
      options, M.session(id: 'hitl'), 'Write a note.'
    )
    [result.output, tool.notes.length, nil]
  rescue Praxo::Error => error
    ['', tool.notes.length, error]
  end

  def self.run(out = $stdout)
    output, effects, error = run_scenario(
      M.interrupt_decision(action: Praxo::Agent::INTERRUPT_APPROVE)
    )
    unless error.nil? && output == 'done' && effects == 1
      raise "approve scenario failed: output=#{output.inspect} effects=#{effects} error=#{error}"
    end
    out.puts 'approve: written; effects=1'

    _, effects, error = run_scenario(
      M.interrupt_decision(
        action: Praxo::Agent::INTERRUPT_EDIT,
        arguments: { 'text' => 'hello', 'visibility' => 'private' }
      )
    )
    unless error && error.code == 'AGENT_POLICY_DENIED' && effects.zero?
      raise "edit scenario failed: effects=#{effects} error=#{error}"
    end
    out.puts 'edit: policy rejected; effects=0'
  end
end

HitlStarter.run if $PROGRAM_NAME == __FILE__
