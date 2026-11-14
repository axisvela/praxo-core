require_relative 'retry'

model = RetryExample::FlakyModel.new(2)
raise 'transient retry failed' unless RetryExample.run(model, 3) == 'status: green'
raise "unexpected calls: #{model.calls}" unless model.calls == 3

exhausted = RetryExample::FlakyModel.new(3)
begin
  RetryExample.run(exhausted, 3)
  raise 'exhausted retry did not fail'
rescue Praxo::Error => error
  raise "unexpected code: #{error.code}" unless error.code == 'MODEL_UNAVAILABLE'
  raise "unexpected calls: #{exhausted.calls}" unless exhausted.calls == 3
end

puts 'ruby retry tests passed'
