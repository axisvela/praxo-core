$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

require 'json'
require 'rack/mock'
require_relative 'config/environment'

app = Rails.application
request = Rack::MockRequest.new(app)

health = request.get('/health')
raise "health failed: #{health.status}" unless health.status == 200

CommerceCopilot.reset_store!
success = request.post('/assistant',
                       input: JSON.generate('message' => 'Find a plan for two seats and draft a cart.'),
                       'CONTENT_TYPE' => 'application/json',
                       'HTTP_X_TENANT' => 'acme')
raise "success failed: #{success.status} #{success.body}" unless success.status == 200
body = JSON.parse(success.body)
raise 'draft was not review-only' unless body.dig('draft', 'status') == 'draft_only'
raise 'payment was charged' unless body['payment_charges'].zero?
raise 'refund was issued' unless body['refunds'].zero?
raise 'unexpected mutating action' unless body['mutating_actions'] == []
raise 'tool trace mismatch' unless body.dig('agent', 'tools') ==
                                   %w[search_catalog quote_cart draft_order]
raise 'draft was not persisted' unless body.dig('agent', 'store', 'drafts') == 1

tenant = request.post('/assistant',
                      input: JSON.generate('message' => 'Show the catalog.'),
                      'CONTENT_TYPE' => 'application/json',
                      'HTTP_X_TENANT' => 'other')
raise "tenant denial failed: #{tenant.status}" unless tenant.status == 403

store = CommerceCopilot::CommerceStore.new
service = CommerceCopilot::AgentService.new(store: store)
charge = service.run(tenant: 'acme', message: 'Charge now.', mode: 'direct')
raise 'direct charge did not fail' unless charge.status == 403
raise 'direct charge had an effect' unless store.counts['charges'].zero?

refund = service.run(tenant: 'acme', message: 'Refund the order.', mode: 'refund')
raise 'direct refund did not fail' unless refund.status == 403
raise 'direct refund had an effect' unless store.counts['refunds'].zero?

weak = service.run(tenant: 'acme', message: 'Draft without review.', mode: 'weak')
raise 'weak draft did not fail' unless weak.status == 403
raise 'weak draft was persisted' unless store.counts['drafts'].zero?

puts 'Ruby AI commerce copilot: all checks passed'
