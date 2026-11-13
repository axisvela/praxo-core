require_relative 'starter'

output, calls, error = Starter.run_scenario('public')
raise "allow: output=#{output.inspect} effects=#{calls} error=#{error}" unless error.nil? && output == 'recorded' && calls == 1

_, calls, error = Starter.run_scenario('private')
raise "deny: effects=#{calls} error=#{error}" unless error && error.message.include?('policy denied') && calls.zero?

puts 'ruby consumer tests passed'
