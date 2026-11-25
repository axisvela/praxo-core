$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

require 'json'
require_relative 'config/environment'

prompt = ENV.fetch(
  'COMMERCE_PROMPT',
  'Find an in-stock plan for two seats, quote the cart, and draft a review-only order.'
)
result = CommerceCopilot::AgentService.new(live: true).run(
  tenant: CommerceCopilot::TENANT, message: prompt
)
puts JSON.generate(result.body)
exit(result.status < 400 ? 0 : 1)
