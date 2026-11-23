require 'json'
require 'praxo'

module FinopsReview
  M = Praxo::Models
  ACCOUNT = 'cloud-100'
  RESOURCES = [
    { 'id' => 'vm-idle', 'utilization' => 2, 'hourly_cost' => 0.5 },
    { 'id' => 'vm-busy', 'utilization' => 80, 'hourly_cost' => 1.0 }
  ].freeze

  class FixtureModel
    def initialize(account)
      @account = account
    end

    def generate(request)
      results = request.messages.select { |message| message.role == M::TOOL }
      if results.empty?
        call = M.tool_call(id: 'cost-1', name: 'read_costs', arguments: { 'account' => @account })
        return M.response(message: M.message_assistant('', [call]))
      end
      costs = JSON.parse(results.first.content)
      if results.length == 1
        call = M.tool_call(id: 'draft-1', name: 'draft_review', arguments: {
          'account' => @account, 'resource' => costs.fetch('candidate'), 'action' => 'review_idle'
        })
        return M.response(message: M.message_assistant('', [call]))
      end
      draft = JSON.parse(results.last.content)
      M.response(message: M.message_assistant(JSON.generate({ 'costs' => costs, 'draft' => draft })))
    end
  end

  def self.run(account = ACCOUNT, failure: false)
    counts = { reads: 0, drafts: 0 }
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(Praxo::Agent::FuncTool.new('read_costs', 'Compute fixed synthetic cloud costs.', lambda do |args|
      raise 'account outside fixture' unless args['account'] == ACCOUNT
      counts[:reads] += 1
      raise 'COST_SOURCE_UNAVAILABLE' if failure
      idle = RESOURCES.select { |resource| resource.fetch('utilization') < 5 }
      candidate = idle.max_by { |resource| resource.fetch('hourly_cost') }
      {
        'account' => ACCOUNT, 'candidate' => candidate.fetch('id'),
        'estimated_monthly_cost' => (candidate.fetch('hourly_cost') * 24 * 30).round(2),
        'basis' => 'fixed 30-day simulation; not guaranteed savings'
      }
    end))
    registry.register(Praxo::Agent::FuncTool.new('draft_review', 'Draft an idle-resource review; never stop instances.', lambda do |args|
      counts[:drafts] += 1
      {
        'account' => args.fetch('account'), 'resource' => args.fetch('resource'),
        'action' => args.fetch('action'), 'status' => 'draft_only',
        'review_required' => true, 'cloud_writes' => 0
      }
    end))
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new(account))
    options.tools = registry
    options.max_steps = 4
    options.allowed_tools = %w[read_costs draft_review]
    options.require_policy = true
    options.require_tool_scope = true
    options.policy = lambda do |action|
      allowed = action.kind == 'model.generate'
      if action.kind == 'tool.invoke' && action.arguments['account'] == ACCOUNT
        allowed = action.tool_name == 'read_costs' || (
          action.tool_name == 'draft_review' && action.arguments['resource'] == 'vm-idle' &&
          action.arguments['action'] == 'review_idle'
        )
      end
      M.decision(allowed: allowed, reason: 'only cloud-100 costs and vm-idle review are permitted')
    end
    result = Praxo::Agent.run_agent(options, M.session(id: 'finops-review'),
                                   'Inspect synthetic resource costs and draft a review of idle capacity.')
    [JSON.parse(result.output), counts, nil]
  rescue StandardError => error
    [nil, counts, error]
  end

  def self.test
    report, counts, error = run
    raise "success failed: #{error}" unless error.nil? && counts == { reads: 1, drafts: 1 }
    raise 'wrong cost evidence' unless report.dig('costs', 'estimated_monthly_cost') == 360.0
    raise 'wrong resource' unless report.dig('draft', 'resource') == 'vm-idle'
    raise 'not draft-only' unless report.dig('draft', 'status') == 'draft_only'
    raise 'unintended write' unless report.dig('draft', 'cloud_writes').zero?
    _, counts, error = run('cloud-200')
    raise 'scope denial failed' unless error && error.message.include?('policy denied') &&
                                      counts == { reads: 0, drafts: 0 }
    _, counts, error = run(ACCOUNT, failure: true)
    raise 'dependency failure failed' unless error && error.message.include?('COST_SOURCE_UNAVAILABLE') &&
                                            counts == { reads: 1, drafts: 0 }
    puts 'Ruby SE-07 FinOps tutorial: success, denial and dependency failure passed'
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ['--test']
    FinopsReview.test
  else
    account = FinopsReview::ACCOUNT
    index = ARGV.index('--account')
    abort 'missing --account value' if index && !ARGV[index + 1]
    account = ARGV[index + 1] if index
    report, counts, error = FinopsReview.run(account, failure: ARGV.include?('--simulate-failure'))
    abort "finops failed: reads=#{counts[:reads]} drafts=#{counts[:drafts]}; #{error}" if error
    puts JSON.generate(report)
  end
end
