require 'praxo'

parts = []
options = Praxo::Agent::AgentOptions.new(Praxo::Agent::StaticModel.new('done'))
options.on_stream = ->(part) { parts << part.kind }
result = Praxo::Agent.run_agent(
  options, Praxo::Models.session(id: 'streaming'), 'go'
)

raise "unexpected output: #{result.output}" unless result.output == 'done'
raise "unexpected parts: #{parts.inspect}" unless parts == %w[values messages]

puts 'Ruby streaming example passed'
