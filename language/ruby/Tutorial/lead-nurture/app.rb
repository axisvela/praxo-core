require 'json'
require 'praxo'

module LeadNurture
  M = Praxo::Models
  CAMPAIGN = 'campaign-100'

  class FixtureModel
    def initialize(campaign)
      @campaign = campaign
    end

    def generate(request)
      results = request.messages.select { |message| message.role == M::TOOL }
      if results.empty?
        call = M.tool_call(id: 'leads-1', name: 'read_leads',
                           arguments: { 'campaign' => @campaign })
        return M.response(message: M.message_assistant('', [call]))
      end
      if results.length == 1
        call = M.tool_call(id: 'outreach-1', name: 'draft_outreach',
                           arguments: { 'campaign' => @campaign, 'action' => 'draft_outreach' })
        return M.response(message: M.message_assistant('', [call]))
      end
      leads = JSON.parse(results.first.content)
      outreach = JSON.parse(results.last.content)
      M.response(message: M.message_assistant(JSON.generate({
        'leads' => leads, 'outreach' => outreach, 'sends' => 0, 'crawls' => 0
      })))
    end
  end

  def self.run(campaign = CAMPAIGN, failure: false)
    counts = { reads: 0, drafts: 0 }
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(Praxo::Agent::FuncTool.new('read_leads',
                                                  'Rank fixed synthetic business profiles; no crawling.', lambda do |args|
      raise 'campaign outside fixture' unless args['campaign'] == CAMPAIGN
      counts[:reads] += 1
      raise 'LEAD_INDEX_UNAVAILABLE' if failure
      {
        'campaign' => CAMPAIGN, 'leads' => 3,
        'ranked' => %w[lead-2 lead-1], 'opt_in' => 1,
        'source' => 'lead_fixture'
      }
    end))
    registry.register(Praxo::Agent::FuncTool.new('draft_outreach',
                                                  'Draft review-only opt-in outreach; never sends.', lambda do |args|
      counts[:drafts] += 1
      {
        'outreach_id' => 'outreach-100', 'campaign' => args.fetch('campaign'),
        'action' => args.fetch('action'), 'lead' => 'lead-2',
        'drafts' => 1, 'status' => 'draft_only', 'review_required' => true,
        'sends' => 0, 'crawls' => 0
      }
    end))
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new(campaign))
    options.tools = registry
    options.max_steps = 4
    options.allowed_tools = %w[read_leads draft_outreach]
    options.require_policy = true
    options.require_tool_scope = true
    options.policy = lambda do |action|
      allowed = action.kind == 'model.generate'
      if action.kind == 'tool.invoke' && action.arguments['campaign'] == CAMPAIGN
        allowed = action.tool_name == 'read_leads' || (
          action.tool_name == 'draft_outreach' && action.arguments['action'] == 'draft_outreach'
        )
      end
      M.decision(allowed: allowed, reason: 'only a campaign-100 opt-in outreach draft is permitted')
    end
    result = Praxo::Agent.run_agent(options, M.session(id: 'lead-nurture'),
                                    'Rank fixed leads and draft review-only opt-in outreach.')
    [JSON.parse(result.output), counts, nil]
  rescue StandardError => error
    [nil, counts, error]
  end

  def self.test
    report, counts, error = run
    raise "success failed: #{error}" unless error.nil? && counts == { reads: 1, drafts: 1 }
    raise 'wrong ranked order' unless report.dig('leads', 'ranked') == %w[lead-2 lead-1]
    raise 'wrong opt-in count' unless report.dig('leads', 'opt_in') == 1
    raise 'not draft-only' unless report.dig('outreach', 'status') == 'draft_only'
    raise 'unintended send' unless report.dig('outreach', 'sends').zero?
    raise 'unintended crawl' unless report.dig('crawls').zero?
    _, counts, error = run('campaign-200')
    raise 'scope denial failed' unless error && error.message.include?('policy denied') &&
                                      counts == { reads: 0, drafts: 0 }
    _, counts, error = run(CAMPAIGN, failure: true)
    raise 'dependency failure failed' unless error && error.message.include?('LEAD_INDEX_UNAVAILABLE') &&
                                            counts == { reads: 1, drafts: 0 }
    puts 'Ruby CS-02 lead-nurture tutorial: success, denial and dependency failure passed'
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ['--test']
    LeadNurture.test
  else
    campaign = LeadNurture::CAMPAIGN
    index = ARGV.index('--campaign')
    abort 'missing --campaign value' if index && !ARGV[index + 1]
    campaign = ARGV[index + 1] if index
    report, counts, error = LeadNurture.run(campaign, failure: ARGV.include?('--simulate-failure'))
    abort "lead nurture failed: reads=#{counts[:reads]} drafts=#{counts[:drafts]}; #{error}" if error
    puts JSON.generate(report)
  end
end
