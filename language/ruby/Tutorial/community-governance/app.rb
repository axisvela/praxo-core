require 'json'
require 'praxo'

module CommunityGovernance
  M = Praxo::Models
  REPO = 'repo-100'

  class FixtureModel
    def initialize(repo)
      @repo = repo
    end

    def generate(request)
      results = request.messages.select { |message| message.role == M::TOOL }
      if results.empty?
        call = M.tool_call(id: 'issues-1', name: 'read_issues',
                           arguments: { 'repo' => @repo })
        return M.response(message: M.message_assistant('', [call]))
      end
      if results.length == 1
        call = M.tool_call(id: 'guidance-1', name: 'draft_guidance',
                           arguments: { 'repo' => @repo, 'action' => 'draft_reviewer_request' })
        return M.response(message: M.message_assistant('', [call]))
      end
      issues = JSON.parse(results.first.content)
      guidance = JSON.parse(results.last.content)
      M.response(message: M.message_assistant(JSON.generate({
        'issues' => issues, 'guidance' => guidance,
        'closures' => 0, 'impersonations' => 0
      })))
    end
  end

  def self.run(repo = REPO, failure: false)
    counts = { reads: 0, drafts: 0 }
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(Praxo::Agent::FuncTool.new('read_issues',
                                                  'Classify fixed synthetic issues for one repository.', lambda do |args|
      raise 'repo outside fixture' unless args['repo'] == REPO
      counts[:reads] += 1
      raise 'ISSUE_INDEX_UNAVAILABLE' if failure
      {
        'repo' => REPO, 'issues' => 4,
        'categories' => { 'bug' => 2, 'docs' => 1, 'question' => 1 },
        'unlabeled' => 1, 'source' => 'issue_fixture'
      }
    end))
    registry.register(Praxo::Agent::FuncTool.new('draft_guidance',
                                                  'Draft review-only contributor guidance and a reviewer request.', lambda do |args|
      counts[:drafts] += 1
      {
        'guidance_id' => 'guidance-100', 'repo' => args.fetch('repo'),
        'action' => args.fetch('action'), 'requests' => 1,
        'status' => 'draft_only', 'review_required' => true,
        'closures' => 0, 'impersonations' => 0
      }
    end))
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new(repo))
    options.tools = registry
    options.max_steps = 4
    options.allowed_tools = %w[read_issues draft_guidance]
    options.require_policy = true
    options.require_tool_scope = true
    options.policy = lambda do |action|
      allowed = action.kind == 'model.generate'
      if action.kind == 'tool.invoke' && action.arguments['repo'] == REPO
        allowed = action.tool_name == 'read_issues' || (
          action.tool_name == 'draft_guidance' && action.arguments['action'] == 'draft_reviewer_request'
        )
      end
      M.decision(allowed: allowed, reason: 'only a repo-100 reviewer request draft is permitted')
    end
    result = Praxo::Agent.run_agent(options, M.session(id: 'community-governance'),
                                    'Classify fixed issues and draft review-only guidance.')
    [JSON.parse(result.output), counts, nil]
  rescue StandardError => error
    [nil, counts, error]
  end

  def self.test
    report, counts, error = run
    raise "success failed: #{error}" unless error.nil? && counts == { reads: 1, drafts: 1 }
    raise 'wrong issue count' unless report.dig('issues', 'issues') == 4
    raise 'wrong unlabeled count' unless report.dig('issues', 'unlabeled') == 1
    raise 'not draft-only' unless report.dig('guidance', 'status') == 'draft_only'
    raise 'should request review' unless report.dig('guidance', 'requests') == 1
    raise 'unintended closure' unless report.dig('guidance', 'closures').zero?
    raise 'unintended impersonation' unless report.dig('impersonations').zero?
    _, counts, error = run('repo-200')
    raise 'scope denial failed' unless error && error.message.include?('policy denied') &&
                                      counts == { reads: 0, drafts: 0 }
    _, counts, error = run(REPO, failure: true)
    raise 'dependency failure failed' unless error && error.message.include?('ISSUE_INDEX_UNAVAILABLE') &&
                                            counts == { reads: 1, drafts: 0 }
    puts 'Ruby OG-04 community-governance tutorial: success, denial and dependency failure passed'
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ['--test']
    CommunityGovernance.test
  else
    repo = CommunityGovernance::REPO
    index = ARGV.index('--repo')
    abort 'missing --repo value' if index && !ARGV[index + 1]
    repo = ARGV[index + 1] if index
    report, counts, error = CommunityGovernance.run(repo, failure: ARGV.include?('--simulate-failure'))
    abort "community governance failed: reads=#{counts[:reads]} drafts=#{counts[:drafts]}; #{error}" if error
    puts JSON.generate(report)
  end
end
