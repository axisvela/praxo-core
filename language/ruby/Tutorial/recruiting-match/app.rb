require 'json'
require 'praxo'

module RecruitingMatch
  M = Praxo::Models
  ROLE = 'role-100'
  CANDIDATES = [
    { 'id' => 'cand-1', 'skills' => %w[go sql], 'years' => 5 },
    { 'id' => 'cand-2', 'skills' => %w[python ml], 'years' => 3 },
    { 'id' => 'cand-3', 'skills' => %w[go sql k8s], 'years' => 7 }
  ].freeze
  REQUIRED = %w[go sql].freeze
  MIN_YEARS = 4

  class FixtureModel
    def initialize(role)
      @role = role
    end

    def generate(request)
      results = request.messages.select { |message| message.role == M::TOOL }
      if results.empty?
        call = M.tool_call(id: 'role-1', name: 'read_role', arguments: { 'role' => @role })
        return M.response(message: M.message_assistant('', [call]))
      end
      summary = JSON.parse(results.first.content)
      if results.length == 1
        call = M.tool_call(id: 'shortlist-1', name: 'draft_shortlist', arguments: {
          'role' => @role, 'action' => 'shortlist', 'candidate' => summary.fetch('ranked').first
        })
        return M.response(message: M.message_assistant('', [call]))
      end
      draft = JSON.parse(results.last.content)
      M.response(message: M.message_assistant(JSON.generate({
        'stage' => 'shortlist_drafted', 'role' => summary, 'shortlist' => draft, 'outreach_sent' => 0
      })))
    end
  end

  def self.run(role = ROLE, failure: false)
    counts = { reads: 0, drafts: 0 }
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(Praxo::Agent::FuncTool.new('read_role', 'Match fixed synthetic candidates against a role.', lambda do |args|
      raise 'role outside fixture' unless args['role'] == ROLE
      counts[:reads] += 1
      raise 'ROLE_SOURCE_UNAVAILABLE' if failure
      matched = CANDIDATES.select do |candidate|
        (REQUIRED - candidate.fetch('skills')).empty? && candidate.fetch('years') >= MIN_YEARS
      end
      ranked = matched.sort_by { |candidate| [-candidate.fetch('years'), candidate.fetch('id')] }
      {
        'role' => ROLE, 'required' => REQUIRED, 'min_years' => MIN_YEARS,
        'ranked' => ranked.map { |candidate| candidate.fetch('id') },
        'matched' => ranked.length, 'source' => 'candidate_fixture'
      }
    end))
    registry.register(Praxo::Agent::FuncTool.new('draft_shortlist', 'Draft a review-only shortlist; never contacts candidates.', lambda do |args|
      counts[:drafts] += 1
      {
        'shortlist_id' => 'shortlist-100', 'role' => args.fetch('role'),
        'candidate' => args.fetch('candidate'), 'action' => args.fetch('action'),
        'status' => 'draft_only', 'review_required' => true, 'outreach_sent' => 0
      }
    end))
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new(role))
    options.tools = registry
    options.max_steps = 4
    options.allowed_tools = %w[read_role draft_shortlist]
    options.require_policy = true
    options.require_tool_scope = true
    options.policy = lambda do |action|
      allowed = action.kind == 'model.generate'
      if action.kind == 'tool.invoke' && action.arguments['role'] == ROLE
        allowed = action.tool_name == 'read_role' || (
          action.tool_name == 'draft_shortlist' && action.arguments['action'] == 'shortlist'
        )
      end
      M.decision(allowed: allowed, reason: 'only role-100 shortlist is permitted')
    end
    result = Praxo::Agent.run_agent(options, M.session(id: 'recruiting-match'),
                                   'Match fixed candidates and draft a review-only shortlist.')
    [JSON.parse(result.output), counts, nil]
  rescue StandardError => error
    [nil, counts, error]
  end

  def self.test
    report, counts, error = run
    raise "success failed: #{error}" unless error.nil? && counts == { reads: 1, drafts: 1 }
    raise 'wrong ranked' unless report.dig('role', 'ranked') == %w[cand-3 cand-1]
    raise 'wrong matched' unless report.dig('role', 'matched') == 2
    raise 'not draft-only' unless report.dig('shortlist', 'status') == 'draft_only'
    raise 'unintended outreach' unless report.dig('shortlist', 'outreach_sent').zero?
    _, counts, error = run('role-200')
    raise 'scope denial failed' unless error && error.message.include?('policy denied') &&
                                      counts == { reads: 0, drafts: 0 }
    _, counts, error = run(ROLE, failure: true)
    raise 'dependency failure failed' unless error && error.message.include?('ROLE_SOURCE_UNAVAILABLE') &&
                                            counts == { reads: 1, drafts: 0 }
    puts 'Ruby OP-05 recruiting-match tutorial: success, denial and dependency failure passed'
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ['--test']
    RecruitingMatch.test
  else
    role = RecruitingMatch::ROLE
    index = ARGV.index('--role')
    abort 'missing --role value' if index && !ARGV[index + 1]
    role = ARGV[index + 1] if index
    report, counts, error = RecruitingMatch.run(role, failure: ARGV.include?('--simulate-failure'))
    abort "recruiting failed: reads=#{counts[:reads]} drafts=#{counts[:drafts]}; #{error}" if error
    puts JSON.generate(report)
  end
end
