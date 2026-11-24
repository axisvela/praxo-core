require 'json'
require 'praxo'

module DueDiligence
  M = Praxo::Models
  TARGET = 'target-100'

  class FixtureModel
    def initialize(target)
      @target = target
    end

    def generate(request)
      results = request.messages.select { |message| message.role == M::TOOL }
      if results.empty?
        call = M.tool_call(id: 'diligence-1', name: 'read_diligence',
                           arguments: { 'target' => @target })
        return M.response(message: M.message_assistant('', [call]))
      end
      if results.length == 1
        call = M.tool_call(id: 'risks-1', name: 'draft_checklist',
                           arguments: { 'target' => @target, 'action' => 'draft_risk_checklist' })
        return M.response(message: M.message_assistant('', [call]))
      end
      diligence = JSON.parse(results.first.content)
      checklist = JSON.parse(results.last.content)
      M.response(message: M.message_assistant(JSON.generate({
        'diligence' => diligence, 'checklist' => checklist,
        'acquisition_conclusions' => 0, 'deal_writes' => 0
      })))
    end
  end

  def self.run(target = TARGET, failure: false)
    counts = { reads: 0, drafts: 0 }
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(Praxo::Agent::FuncTool.new('read_diligence',
                                                  'Reconcile fixed ownership, contract and dispute fixtures.', lambda do |args|
      raise 'target outside fixture' unless args['target'] == TARGET
      counts[:reads] += 1
      raise 'DILIGENCE_SOURCE_UNAVAILABLE' if failure
      {
        'target' => TARGET, 'ownership_entities' => 2, 'contracts' => 5,
        'disputes' => 1, 'flags' => %w[change_of_control],
        'source' => 'diligence_fixture'
      }
    end))
    registry.register(Praxo::Agent::FuncTool.new('draft_checklist',
                                                  'Draft a review-only risk checklist; never concludes a deal.', lambda do |args|
      counts[:drafts] += 1
      {
        'checklist_id' => 'diligence-100', 'target' => args.fetch('target'),
        'action' => args.fetch('action'),
        'risks' => ['consent required for change of control', 'verify dispute reserve', 'confirm IP assignment'],
        'status' => 'draft_only', 'review_required' => true,
        'acquisition_conclusions' => 0, 'deal_writes' => 0
      }
    end))
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new(target))
    options.tools = registry
    options.max_steps = 4
    options.allowed_tools = %w[read_diligence draft_checklist]
    options.require_policy = true
    options.require_tool_scope = true
    options.policy = lambda do |action|
      allowed = action.kind == 'model.generate'
      if action.kind == 'tool.invoke' && action.arguments['target'] == TARGET
        allowed = action.tool_name == 'read_diligence' || (
          action.tool_name == 'draft_checklist' && action.arguments['action'] == 'draft_risk_checklist'
        )
      end
      M.decision(allowed: allowed, reason: 'only a target-100 risk checklist draft is permitted')
    end
    result = Praxo::Agent.run_agent(options, M.session(id: 'due-diligence'),
                                    'Reconcile the fixed target and draft a review-only risk checklist.')
    [JSON.parse(result.output), counts, nil]
  rescue StandardError => error
    [nil, counts, error]
  end

  def self.test
    report, counts, error = run
    raise "success failed: #{error}" unless error.nil? && counts == { reads: 1, drafts: 1 }
    raise 'wrong entity count' unless report.dig('diligence', 'ownership_entities') == 2
    raise 'wrong dispute count' unless report.dig('diligence', 'disputes') == 1
    raise 'missing change_of_control' unless report.dig('diligence', 'flags') == ['change_of_control']
    raise 'not draft-only' unless report.dig('checklist', 'status') == 'draft_only'
    raise 'should have three risks' unless report.dig('checklist', 'risks').length == 3
    raise 'unintended conclusion' unless report.dig('acquisition_conclusions').zero?
    _, counts, error = run('target-200')
    raise 'scope denial failed' unless error && error.message.include?('policy denied') &&
                                      counts == { reads: 0, drafts: 0 }
    _, counts, error = run(TARGET, failure: true)
    raise 'dependency failure failed' unless error && error.message.include?('DILIGENCE_SOURCE_UNAVAILABLE') &&
                                            counts == { reads: 1, drafts: 0 }
    puts 'Ruby LJ-03 due-diligence tutorial: success, denial and dependency failure passed'
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ['--test']
    DueDiligence.test
  else
    target = DueDiligence::TARGET
    index = ARGV.index('--target')
    abort 'missing --target value' if index && !ARGV[index + 1]
    target = ARGV[index + 1] if index
    report, counts, error = DueDiligence.run(target, failure: ARGV.include?('--simulate-failure'))
    abort "due diligence failed: reads=#{counts[:reads]} drafts=#{counts[:drafts]}; #{error}" if error
    puts JSON.generate(report)
  end
end
