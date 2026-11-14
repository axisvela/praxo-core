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

puts 'Ruby service example passed'
