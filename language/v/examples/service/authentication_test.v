module main

import encoding.base64

fn canned_transport(status int, body string) IntrospectionTransport {
	return fn [status, body] (_url string, _form map[string]string, _authorization ?string) !TransportResponse {
		return TransportResponse{
			status: status
			body: body
		}
	}
}

fn failing_transport() IntrospectionTransport {
	return fn (_url string, _form map[string]string, _authorization ?string) !TransportResponse {
		return error('identity provider unavailable')
	}
}

fn test_introspection_success() {
	now := 1700000000
	expected_basic := 'Basic ' + base64.encode('client:secret'.bytes())
	transport := fn [now, expected_basic] (url string, form map[string]string, authorization ?string) !TransportResponse {
		assert url == 'https://id.example.com/introspect'
		assert form['token'] == 'opaque-token'
		assert form['client_id'] == 'client'
		assert form['client_secret'] == 'secret'
		assert (authorization or { '' }) == expected_basic
		return TransportResponse{
			status: 200
			body: '{"active":true,"sub":"user-1","tenant":"local","exp":${now + 60}}'
		}
	}
	authenticator := new_introspection_authenticator(transport,
		'https://id.example.com/introspect', 'client', 'secret', 'tenant')
	principal := authenticate(authenticator, 'Bearer opaque-token', now) or {
		assert false, 'active token was rejected'
		return
	}
	assert principal.subject == 'user-1'
	assert principal.tenant == 'local'
	assert principal.expires == now + 60
}

fn test_introspection_without_client_id_omits_basic_auth() {
	now := 1700000000
	transport := fn [now] (_url string, form map[string]string, authorization ?string) !TransportResponse {
		assert form['token'] == 'opaque-token'
		if _ := authorization {
			assert false, 'basic auth should be omitted without a client id'
		}
		return TransportResponse{
			status: 200
			body: '{"active":true,"sub":"user-1","tenant":"local","exp":${now + 60}}'
		}
	}
	authenticator := new_introspection_authenticator(transport,
		'https://id.example.com/introspect', '', '', 'tenant')
	principal := authenticate(authenticator, 'Bearer opaque-token', now) or {
		assert false, 'active token was rejected'
		return
	}
	assert principal.subject == 'user-1'
}

fn test_introspection_rejects_wrong_scheme() {
	now := 1700000000
	authenticator := new_introspection_authenticator(canned_transport(200, '{}'),
		'https://id.example.com/introspect', '', '', 'tenant')
	if _ := authenticate(authenticator, none, now) {
		assert false, 'missing authorization was accepted'
	}
	if _ := authenticate(authenticator, '', now) {
		assert false, 'empty authorization was accepted'
	}
	if _ := authenticate(authenticator, 'Basic abc', now) {
		assert false, 'wrong scheme was accepted'
	}
	if _ := authenticate(authenticator, 'bearer token', now) {
		assert false, 'lowercase scheme was accepted'
	}
	if _ := authenticate(authenticator, 'Token abc', now) {
		assert false, 'unknown scheme was accepted'
	}
}

fn test_introspection_rejects_empty_token() {
	now := 1700000000
	authenticator := new_introspection_authenticator(canned_transport(200, '{}'),
		'https://id.example.com/introspect', '', '', 'tenant')
	if _ := authenticate(authenticator, 'Bearer ', now) {
		assert false, 'empty token was accepted'
	}
	if _ := authenticate(authenticator, 'Bearer    ', now) {
		assert false, 'blank token was accepted'
	}
}

fn test_introspection_rejects_inactive() {
	now := 1700000000
	authenticator := new_introspection_authenticator(
		canned_transport(200, '{"active":false}'),
		'https://id.example.com/introspect', '', '', 'tenant',
	)
	if _ := authenticate(authenticator, 'Bearer opaque-token', now) {
		assert false, 'inactive token was accepted'
	}
}

fn test_introspection_rejects_missing_sub() {
	now := 1700000000
	authenticator := new_introspection_authenticator(
		canned_transport(200, '{"active":true,"tenant":"local","exp":${now + 60}}'),
		'https://id.example.com/introspect', '', '', 'tenant',
	)
	if _ := authenticate(authenticator, 'Bearer opaque-token', now) {
		assert false, 'missing sub was accepted'
	}
}

fn test_introspection_rejects_empty_sub() {
	now := 1700000000
	authenticator := new_introspection_authenticator(
		canned_transport(200, '{"active":true,"sub":"","tenant":"local","exp":${now + 60}}'),
		'https://id.example.com/introspect', '', '', 'tenant',
	)
	if _ := authenticate(authenticator, 'Bearer opaque-token', now) {
		assert false, 'empty sub was accepted'
	}
}

fn test_introspection_rejects_missing_tenant() {
	now := 1700000000
	authenticator := new_introspection_authenticator(
		canned_transport(200, '{"active":true,"sub":"user-1","exp":${now + 60}}'),
		'https://id.example.com/introspect', '', '', 'tenant',
	)
	if _ := authenticate(authenticator, 'Bearer opaque-token', now) {
		assert false, 'missing tenant was accepted'
	}
}

fn test_introspection_rejects_empty_tenant() {
	now := 1700000000
	authenticator := new_introspection_authenticator(
		canned_transport(200, '{"active":true,"sub":"user-1","tenant":"","exp":${now + 60}}'),
		'https://id.example.com/introspect', '', '', 'tenant',
	)
	if _ := authenticate(authenticator, 'Bearer opaque-token', now) {
		assert false, 'empty tenant was accepted'
	}
}

fn test_introspection_rejects_expired() {
	now := 1700000000
	at_now := new_introspection_authenticator(
		canned_transport(200, '{"active":true,"sub":"user-1","tenant":"local","exp":${now}}'),
		'https://id.example.com/introspect', '', '', 'tenant',
	)
	if _ := authenticate(at_now, 'Bearer opaque-token', now) {
		assert false, 'token expiring now was accepted'
	}
	before := new_introspection_authenticator(
		canned_transport(200, '{"active":true,"sub":"user-1","tenant":"local","exp":${now - 1}}'),
		'https://id.example.com/introspect', '', '', 'tenant',
	)
	if _ := authenticate(before, 'Bearer opaque-token', now) {
		assert false, 'expired token was accepted'
	}
}

fn test_introspection_rejects_malformed_json() {
	now := 1700000000
	authenticator := new_introspection_authenticator(canned_transport(200, '{not json'),
		'https://id.example.com/introspect', '', '', 'tenant')
	if _ := authenticate(authenticator, 'Bearer opaque-token', now) {
		assert false, 'malformed JSON was accepted'
	}
}

fn test_introspection_rejects_non_200() {
	now := 1700000000
	authenticator := new_introspection_authenticator(
		canned_transport(401, '{"active":true,"sub":"user-1","tenant":"local","exp":${now + 60}}'),
		'https://id.example.com/introspect', '', '', 'tenant',
	)
	if _ := authenticate(authenticator, 'Bearer opaque-token', now) {
		assert false, 'non-200 response was accepted'
	}
}

fn test_introspection_rejects_transport_error() {
	now := 1700000000
	authenticator := new_introspection_authenticator(failing_transport(),
		'https://id.example.com/introspect', '', '', 'tenant')
	if _ := authenticate(authenticator, 'Bearer opaque-token', now) {
		assert false, 'transport error was accepted'
	}
}

fn test_introspection_custom_tenant_claim() {
	now := 1700000000
	authenticator := new_introspection_authenticator(
		canned_transport(200, '{"active":true,"sub":"user-1","org":"acme","exp":${now + 60}}'),
		'https://id.example.com/introspect', '', '', 'org',
	)
	principal := authenticate(authenticator, 'Bearer opaque-token', now) or {
		assert false, 'custom tenant claim was rejected'
		return
	}
	assert principal.tenant == 'acme'
}

fn test_revocation_success() {
	transport := fn (url string, form map[string]string, authorization ?string) !TransportResponse {
		assert url == 'https://id.example.com/revoke'
		assert form['token'] == 'opaque-token'
		assert form['token_type_hint'] == 'access_token'
		assert form['client_id'] == 'client'
		assert form['client_secret'] == 'secret'
		assert (authorization or { '' }) == 'Basic ' + base64.encode('client:secret'.bytes())
		return TransportResponse{
			status: 200
			body: '{}'
		}
	}
	revoker := new_revocation_client(transport, 'https://id.example.com/revoke',
		'client', 'secret')
	_ := revoke(revoker, 'opaque-token') or {
		assert false, 'revocation failed'
		return
	}
}

fn test_revocation_rejects_non_200() {
	revoker := new_revocation_client(canned_transport(503, '{}'),
		'https://id.example.com/revoke', 'client', 'secret')
	_ := revoke(revoker, 'opaque-token') or {
		assert err.msg() == 'token revocation failed'
		return
	}
	assert false, 'revocation non-200 was accepted'
}

fn test_revocation_rejects_transport_error() {
	revoker := new_revocation_client(failing_transport(),
		'https://id.example.com/revoke', 'client', 'secret')
	_ := revoke(revoker, 'opaque-token') or {
		assert err.msg() == 'token revocation failed'
		return
	}
	assert false, 'revocation transport error was accepted'
}

fn test_revocation_rejects_empty_token() {
	revoker := new_revocation_client(canned_transport(200, '{}'),
		'https://id.example.com/revoke', 'client', 'secret')
	_ := revoke(revoker, '') or {
		assert err.msg() == 'revocation token is required'
		return
	}
	assert false, 'empty revocation token was accepted'
}
