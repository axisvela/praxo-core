require_relative 'authentication'

class ScriptedTransport
  attr_reader :forms

  def initialize(status, body)
    @status = status
    @body = body
    @forms = []
    @unavailable = false
  end

  def unavailable!
    @unavailable = true
  end

  def post_form(_url, form, _authorization)
    @forms << form
    raise ServiceAuth::AuthError, 'identity provider unavailable' if @unavailable

    [@status, @body]
  end
end

module ServiceExample
  def self.handle(method, path, principal, body)
    return [200, { 'status' => 'ok' }] if method == 'GET' && path == '/healthz'
    return [404, { 'error' => 'not found' }] unless method == 'POST' && path == '/run'
    return [401, { 'error' => 'missing X-Praxo-Principal' }] if principal.nil? || principal.empty?
    return [400, { 'error' => 'prompt is required' }] unless body.include?('"prompt"')

    [200, { 'output' => 'hello from the service' }]
  end
end

status, body = ServiceExample.handle('GET', '/healthz', nil, '')
raise 'health failed' unless status == 200 && body['status'] == 'ok'

status, = ServiceExample.handle('POST', '/run', nil, '{"prompt":"hi"}')
raise 'missing principal was accepted' unless status == 401

status, body = ServiceExample.handle('POST', '/run', 'user-1', '{"prompt":"hi"}')
raise 'run failed' unless status == 200 && body['output'] == 'hello from the service'

now = Time.now.to_i
active = ScriptedTransport.new(200, JSON.generate(
  'active' => true, 'sub' => 'user-1', 'tenant' => 'local', 'exp' => now + 60
))
authenticator = ServiceAuth::IntrospectionAuthenticator.new(
  transport: active, endpoint: 'https://id.example.com/introspect'
)
principal = authenticator.authenticate('Bearer opaque-token', now)
raise 'active token was rejected' unless principal&.subject == 'user-1' &&
  principal.tenant == 'local'

inactive = ScriptedTransport.new(200, JSON.generate('active' => false))
inactive_auth = ServiceAuth::IntrospectionAuthenticator.new(
  transport: inactive, endpoint: 'https://id.example.com/introspect'
)
raise 'inactive token was accepted' unless inactive_auth.authenticate('Bearer opaque-token', now).nil?

missing = ScriptedTransport.new(200, JSON.generate(
  'active' => true, 'sub' => 'user-1', 'tenant' => 'local'
))
missing_auth = ServiceAuth::IntrospectionAuthenticator.new(
  transport: missing, endpoint: 'https://id.example.com/introspect'
)
raise 'missing expiration was accepted' unless missing_auth.authenticate('Bearer opaque-token', now).nil?

unavailable = ScriptedTransport.new(200, '{}')
unavailable.unavailable!
unavailable_auth = ServiceAuth::IntrospectionAuthenticator.new(
  transport: unavailable, endpoint: 'https://id.example.com/introspect'
)
raise 'unavailable provider was accepted' unless unavailable_auth.authenticate('Bearer opaque-token', now).nil?

revocation = ServiceAuth::RevocationClient.new(
  transport: active, endpoint: 'https://id.example.com/revoke'
)
revocation.revoke('opaque-token')
raise 'revocation did not post the token' unless active.forms.last.include?('token=opaque-token')

failed_revocation = ScriptedTransport.new(503, '{}')
failed_client = ServiceAuth::RevocationClient.new(
  transport: failed_revocation, endpoint: 'https://id.example.com/revoke'
)
begin
  failed_client.revoke('opaque-token')
  raise 'revocation failure was accepted'
rescue ServiceAuth::AuthError
end

context = ServiceAuth::ContextAuthenticator.new('local')
raise 'context principal failed' unless context.authenticate('user-1')&.tenant == 'local'

puts 'Ruby service example passed'
puts 'Ruby service auth tests passed'
