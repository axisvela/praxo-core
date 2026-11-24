require 'json'
require 'praxo'

module RetailReplenishment
  M = Praxo::Models
  SKU = 'sku-100'
  STOCK = 8
  DAILY_SALES = 5
  LEAD_DAYS = 3
  SAFETY_DAYS = 3

  class FixtureModel
    def initialize(sku)
      @sku = sku
    end

    def generate(request)
      results = request.messages.select { |message| message.role == M::TOOL }
      if results.empty?
        call = M.tool_call(id: 'stock-1', name: 'read_sku', arguments: { 'sku' => @sku })
        return M.response(message: M.message_assistant('', [call]))
      end
      stock = JSON.parse(results.first.content)
      if results.length == 1
        action = stock['reorder_qty'].positive? ? 'draft_po' : 'hold'
        call = M.tool_call(id: 'order-1', name: 'draft_order',
                           arguments: { 'sku' => @sku, 'action' => action })
        return M.response(message: M.message_assistant('', [call]))
      end
      order = JSON.parse(results.last.content)
      M.response(message: M.message_assistant(JSON.generate({
        'sku' => stock, 'order' => order, 'purchases_submitted' => 0
      })))
    end
  end

  def self.run(sku = SKU, failure: false)
    counts = { reads: 0, drafts: 0 }
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(Praxo::Agent::FuncTool.new('read_sku',
                                                  'Compute a fixed reorder quantity from stock and sales.', lambda do |args|
      raise 'sku outside fixture' unless args['sku'] == SKU
      counts[:reads] += 1
      raise 'STOCK_UNAVAILABLE' if failure
      target = DAILY_SALES * (LEAD_DAYS + SAFETY_DAYS)
      {
        'sku' => SKU, 'stock' => STOCK, 'daily_sales' => DAILY_SALES,
        'lead_days' => LEAD_DAYS, 'reorder_qty' => [target - STOCK, 0].max,
        'source' => 'stock_fixture'
      }
    end))
    registry.register(Praxo::Agent::FuncTool.new('draft_order',
                                                  'Draft a review-only purchase order; never submits.', lambda do |args|
      counts[:drafts] += 1
      {
        'order_id' => 'po-100', 'sku' => args.fetch('sku'),
        'action' => args.fetch('action'), 'quantity' => 22,
        'status' => 'draft_only', 'review_required' => true, 'purchases_submitted' => 0
      }
    end))
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new(sku))
    options.tools = registry
    options.max_steps = 4
    options.allowed_tools = %w[read_sku draft_order]
    options.require_policy = true
    options.require_tool_scope = true
    options.policy = lambda do |action|
      allowed = action.kind == 'model.generate'
      if action.kind == 'tool.invoke' && action.arguments['sku'] == SKU
        allowed = action.tool_name == 'read_sku' || (
          action.tool_name == 'draft_order' &&
          %w[draft_po hold].include?(action.arguments['action'])
        )
      end
      M.decision(allowed: allowed, reason: 'only a sku-100 review draft is permitted')
    end
    result = Praxo::Agent.run_agent(options, M.session(id: 'retail-replenishment'),
                                    'Compute a fixed reorder and draft a review-only order.')
    [JSON.parse(result.output), counts, nil]
  rescue StandardError => error
    [nil, counts, error]
  end

  def self.test
    report, counts, error = run
    raise "success failed: #{error}" unless error.nil? && counts == { reads: 1, drafts: 1 }
    raise 'reorder calculation failed' unless report.dig('sku', 'reorder_qty') == 22
    raise 'not draft-only' unless report.dig('order', 'status') == 'draft_only'
    raise 'unintended purchase' unless report.dig('purchases_submitted').zero?
    _, counts, error = run('sku-200')
    raise 'scope denial failed' unless error && error.message.include?('policy denied') &&
                                      counts == { reads: 0, drafts: 0 }
    _, counts, error = run(SKU, failure: true)
    raise 'dependency failure failed' unless error && error.message.include?('STOCK_UNAVAILABLE') &&
                                            counts == { reads: 1, drafts: 0 }
    puts 'Ruby CS-05 retail-replenishment tutorial: success, denial and dependency failure passed'
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ['--test']
    RetailReplenishment.test
  else
    sku = RetailReplenishment::SKU
    index = ARGV.index('--sku')
    abort 'missing --sku value' if index && !ARGV[index + 1]
    sku = ARGV[index + 1] if index
    report, counts, error = RetailReplenishment.run(sku, failure: ARGV.include?('--simulate-failure'))
    abort "replenishment failed: reads=#{counts[:reads]} drafts=#{counts[:drafts]}; #{error}" if error
    puts JSON.generate(report)
  end
end
