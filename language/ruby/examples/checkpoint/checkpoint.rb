require 'praxo'

allow = Praxo::Runtime::CheckpointAllowlist.new
allow.register('order')
encoded = allow.marshal('order', { 'value' => 'x' })
decoded = allow.unmarshal(encoded)
raise 'checkpoint payload did not round trip' unless decoded == { 'value' => 'x' }

begin
  allow.marshal('missing', {})
  raise 'unregistered type was accepted'
rescue Praxo::Error => error
  raise "unexpected code: #{error.code}" unless error.code == 'CHECKPOINT_TYPE_NOT_ALLOWED'
end

puts 'Ruby checkpoint example passed'
