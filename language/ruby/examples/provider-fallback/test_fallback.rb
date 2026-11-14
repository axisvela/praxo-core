require_relative 'fallback'

primary = ProviderFallbackExample::StaticModel.new('primary response')
fallback = ProviderFallbackExample::StaticModel.new('fallback response')
raise 'primary path failed' unless ProviderFallbackExample.run(primary, fallback) == 'primary response'
raise 'fallback was called' unless fallback.calls.zero?

failing = ProviderFallbackExample::FailingModel.new
used = ProviderFallbackExample::StaticModel.new('fallback response')
raise 'fallback path failed' unless ProviderFallbackExample.run(failing, used) == 'fallback response'

begin
  ProviderFallbackExample.run(
    ProviderFallbackExample::FailingModel.new,
    ProviderFallbackExample::FailingModel.new
  )
  raise 'both-failure path did not reject'
rescue Praxo::Error => error
  raise "unexpected code: #{error.code}" unless error.code == 'MODEL_UNAVAILABLE'
end

puts 'Ruby provider fallback tests passed'
