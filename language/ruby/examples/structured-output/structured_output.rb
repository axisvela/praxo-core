require 'praxo'

SCHEMA = {
  'type' => 'object',
  'required' => ['name'],
  'properties' => { 'name' => { 'type' => 'string' } }
}.freeze

output, code = Praxo::Middleware.structured_apply(SCHEMA, '{"name":"ok"}', 0)
raise 'valid output was rejected' unless output == '{"name":"ok"}' && code.nil?

output, code = Praxo::Middleware.structured_apply(SCHEMA, '{}', 0)
raise 'invalid output was accepted' unless output.nil? && code == 'AGENT_STRUCTURED_OUTPUT'

puts 'Ruby structured output example passed'
