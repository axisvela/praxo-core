require 'json'
require 'praxo'

module SupplyDisruption
  M = Praxo::Models
  NETWORK = 'network-100'

  class FixtureModel
    def initialize(network)
      @network = network
    end

    def generate(request)
      results = request.messages.select { |message| message.role == M::TOOL }
      if results.empty?
        call = M.tool_call(id: 'network-1', name: 'read_supply',
                           arguments: { 'network' => @network })
        return M.response(message: M.message_assistant('', [call]))
      end
      supply = JSON.parse(results.first.content)
      if results.length == 1
        call = M.tool_call(id: 'plan-1', name: 'draft_plan',
                           arguments: { 'network' => @network, 'action' => 'draft_alternative' })
        return M.response(message: M.message_assistant('', [call]))
      end
      plan = JSON.parse(results.last.content)
      M.response(message: M.message_assistant(JSON.generate({
        'supply' => supply, 'plan' => plan, 'purchase_orders' => 0
      })))
    end
  end

  def self.run(network = NETWORK, failure: false)
    counts = { reads: 0, drafts: 0 }
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(Praxo::Agent::FuncTool.new('read_supply',
                                                  'Score a fixed supplier network and choose an alternative.', lambda do |args|
      raise 'network outside fixture' unless args['network'] == NETWORK
      counts[:reads] += 1
      raise 'SUPPLY_INDEX_UNAVAILABLE' if failure
      {
        'network' => NETWORK, 'suppliers' => 3, 'disruption' => 'port-closure',
        'alternate' => 'supplier-2', 'lead_days' => 9, 'source' => 'supply_fixture'
      }
    end))
    registry.register(Praxo::Agent::FuncTool.new('draft_plan',
                                                  'Draft a review-only sourcing plan; never issues POs.', lambda do |args|
      counts[:drafts] += 1
      {
        'plan_id' => 'sourcing-100', 'network' => args.fetch('network'),
        'action' => args.fetch('action'), 'alternate' => 'supplier-2',
        'status' => 'draft_only', 'review_required' => true, 'purchase_orders' => 0
      }
    end))
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new(network))
    options.tools = registry
    options.max_steps = 4
    options.allowed_tools = %w[read_supply draft_plan]
    options.require_policy = true
    options.require_tool_scope = true
    options.policy = lambda do |action|
      allowed = action.kind == 'model.generate'
      if action.kind == 'tool.invoke' && action.arguments['network'] == NETWORK
        allowed = action.tool_name == 'read_supply' || (
          action.tool_name == 'draft_plan' && action.arguments['action'] == 'draft_alternative'
        )
      end
      M.decision(allowed: allowed, reason: 'only a network-100 alternative draft is permitted')
    end
    result = Praxo::Agent.run_agent(options, M.session(id: 'supply-disruption'),
                                    'Rank fixed suppliers and draft a review-only alternative.')
    [JSON.parse(result.output), counts, nil]
  rescue StandardError => error
    [nil, counts, error]
  end

  def self.test
    report, counts, error = run
    raise "success failed: #{error}" unless error.nil? && counts == { reads: 1, drafts: 1 }
    raise 'wrong alternate' unless report.dig('supply', 'alternate') == 'supplier-2'
    raise 'not draft-only' unless report.dig('plan', 'status') == 'draft_only'
    raise 'unintended PO' unless report.dig('purchase_orders').zero?
    _, counts, error = run('network-200')
    raise 'scope denial failed' unless error && error.message.include?('policy denied') &&
                                      counts == { reads: 0, drafts: 0 }
    _, counts, error = run(NETWORK, failure: true)
    raise 'dependency failure failed' unless error && error.message.include?('SUPPLY_INDEX_UNAVAILABLE') &&
                                            counts == { reads: 1, drafts: 0 }
    puts 'Ruby IN-03 supply-disruption tutorial: success, denial and dependency failure passed'
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ['--test']
    SupplyDisruption.test
  else
    network = SupplyDisruption::NETWORK
    index = ARGV.index('--network')
    abort 'missing --network value' if index && !ARGV[index + 1]
    network = ARGV[index + 1] if index
    report, counts, error = SupplyDisruption.run(network, failure: ARGV.include?('--simulate-failure'))
    abort "supply disruption failed: reads=#{counts[:reads]} drafts=#{counts[:drafts]}; #{error}" if error
    puts JSON.generate(report)
  end
end
