struct Response {
	status int
	body   string
}

fn handle(method string, path string, principal string, body string) Response {
	if method == 'GET' && path == '/healthz' {
		return Response{status: 200, body: '{"status":"ok"}'}
	}
	if method != 'POST' || path != '/run' {
		return Response{status: 404, body: '{"error":"not found"}'}
	}
	if principal == '' {
		return Response{status: 401, body: '{"error":"missing X-Praxo-Principal"}'}
	}
	if !body.contains('"prompt"') {
		return Response{status: 400, body: '{"error":"prompt is required"}'}
	}
	return Response{status: 200, body: '{"output":"hello from the service"}'}
}

fn main() {
	assert handle('GET', '/healthz', '', '').status == 200
	assert handle('POST', '/run', '', '{"prompt":"hi"}').status == 401
	assert handle('POST', '/run', 'user-1', '{"prompt":"hi"}').status == 200
	println('V service example passed')
}
