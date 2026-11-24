require 'json'
require 'praxo'

module SupplyChainReview
  M = Praxo::Models
  PACKAGE = 'pkg-100'

  class FixtureModel
    def initialize(package)
      @package = package
    end

    def generate(request)
      results = request.messages.select { |message| message.role == M::TOOL }
      if results.empty?
        call = M.tool_call(id: 'compare-1', name: 'compare_manifests',
                           arguments: { 'package' => @package })
        return M.response(message: M.message_assistant('', [call]))
      end
      if results.length == 1
        call = M.tool_call(id: 'pin-1', name: 'propose_pin',
                           arguments: { 'package' => @package, 'action' => 'hold_pinned_version' })
        return M.response(message: M.message_assistant('', [call]))
      end
      comparison = JSON.parse(results.first.content)
      pin = JSON.parse(results.last.content)
      M.response(message: M.message_assistant(JSON.generate({
        'comparison' => comparison, 'pin' => pin,
        'auto_updates' => 0, 'verifications' => 0
      })))
    end
  end

  def self.run(package = PACKAGE, failure: false)
    counts = { reads: 0, drafts: 0 }
    registry = Praxo::Agent::ToolRegistry.new
    registry.register(Praxo::Agent::FuncTool.new('compare_manifests',
                                                  'Compare a fixed pinned manifest with the registry copy.', lambda do |args|
      raise 'package outside fixture' unless args['package'] == PACKAGE
      counts[:reads] += 1
      raise 'MANIFEST_SOURCE_UNAVAILABLE' if failure
      {
        'package' => PACKAGE, 'pinned' => '1.2.0', 'registry' => '1.2.1',
        'maintainer_changed' => true, 'checksum_match' => false,
        'signals' => %w[maintainer-change checksum-mismatch],
        'source' => 'manifest_fixture'
      }
    end))
    registry.register(Praxo::Agent::FuncTool.new('propose_pin',
                                                  'Propose a reviewed version pin; never updates dependencies.', lambda do |args|
      counts[:drafts] += 1
      {
        'pin_id' => 'pin-100', 'package' => args.fetch('package'),
        'version' => '1.2.0', 'action' => args.fetch('action'),
        'status' => 'draft_only', 'review_required' => true,
        'auto_updates' => 0, 'verifications' => 0
      }
    end))
    options = Praxo::Agent::AgentOptions.new(FixtureModel.new(package))
    options.tools = registry
    options.max_steps = 4
    options.allowed_tools = %w[compare_manifests propose_pin]
    options.require_policy = true
    options.require_tool_scope = true
    options.policy = lambda do |action|
      allowed = action.kind == 'model.generate'
      if action.kind == 'tool.invoke' && action.arguments['package'] == PACKAGE
        allowed = action.tool_name == 'compare_manifests' || (
          action.tool_name == 'propose_pin' && action.arguments['action'] == 'hold_pinned_version'
        )
      end
      M.decision(allowed: allowed, reason: 'only a pkg-100 hold_pinned_version proposal is permitted')
    end
    result = Praxo::Agent.run_agent(options, M.session(id: 'supply-chain-review'),
                                    'Compare the fixed manifest and propose a reviewed pin.')
    [JSON.parse(result.output), counts, nil]
  rescue StandardError => error
    [nil, counts, error]
  end

  def self.test
    report, counts, error = run
    raise "success failed: #{error}" unless error.nil? && counts == { reads: 1, drafts: 1 }
    raise 'wrong signals' unless report.dig('comparison', 'signals') == %w[maintainer-change checksum-mismatch]
    raise 'checksum should mismatch' unless report.dig('comparison', 'checksum_match') == false
    raise 'not draft-only' unless report.dig('pin', 'status') == 'draft_only'
    raise 'should hold pinned version' unless report.dig('pin', 'version') == '1.2.0'
    raise 'unintended updates' unless report.dig('pin', 'auto_updates').zero?
    _, counts, error = run('pkg-200')
    raise 'scope denial failed' unless error && error.message.include?('policy denied') &&
                                      counts == { reads: 0, drafts: 0 }
    _, counts, error = run(PACKAGE, failure: true)
    raise 'dependency failure failed' unless error && error.message.include?('MANIFEST_SOURCE_UNAVAILABLE') &&
                                            counts == { reads: 1, drafts: 0 }
    puts 'Ruby CY-07 supply-chain-review tutorial: success, denial and dependency failure passed'
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ['--test']
    SupplyChainReview.test
  else
    package = SupplyChainReview::PACKAGE
    index = ARGV.index('--package')
    abort 'missing --package value' if index && !ARGV[index + 1]
    package = ARGV[index + 1] if index
    report, counts, error = SupplyChainReview.run(package, failure: ARGV.include?('--simulate-failure'))
    abort "supply-chain review failed: reads=#{counts[:reads]} drafts=#{counts[:drafts]}; #{error}" if error
    puts JSON.generate(report)
  end
end
