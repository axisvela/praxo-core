module main

import encoding.base64
import praxo

struct Principal {
	subject string
	tenant  string
	expires int
}

struct TransportResponse {
	status int
	body   string
}

type IntrospectionTransport = fn (url string, form map[string]string, authorization ?string) !TransportResponse

struct IntrospectionAuthenticator {
	transport     IntrospectionTransport
	endpoint      string
	client_id     string
	client_secret string
	tenant_claim  string
}

struct RevocationClient {
	transport     IntrospectionTransport
	endpoint      string
	client_id     string
	client_secret string
}

fn basic_auth(client_id string, client_secret string) ?string {
	if client_id == '' {
		return none
	}
	return 'Basic ' + base64.encode('${client_id}:${client_secret}'.bytes())
}

fn new_introspection_authenticator(
	transport IntrospectionTransport
	endpoint string
	client_id string
	client_secret string
	tenant_claim string
) IntrospectionAuthenticator {
	claim := if tenant_claim == '' { 'tenant' } else { tenant_claim }
	return IntrospectionAuthenticator{
		transport: transport
		endpoint: endpoint
		client_id: client_id
		client_secret: client_secret
		tenant_claim: claim
	}
}

fn new_revocation_client(
	transport IntrospectionTransport
	endpoint string
	client_id string
	client_secret string
) RevocationClient {
	return RevocationClient{
		transport: transport
		endpoint: endpoint
		client_id: client_id
		client_secret: client_secret
	}
}

fn authenticate(authenticator IntrospectionAuthenticator, authorization ?string, now int) ?Principal {
	value := authorization or { return none }
	if !value.starts_with('Bearer ') {
		return none
	}
	token := value[7..].trim_space()
	if token == '' {
		return none
	}
	form := {
		'token': token
		'client_id': authenticator.client_id
		'client_secret': authenticator.client_secret
	}
	response := authenticator.transport(authenticator.endpoint, form,
		basic_auth(authenticator.client_id, authenticator.client_secret)) or {
		return none
	}
	if response.status != 200 {
		return none
	}
	payload := praxo.parse_json(response.body) or { return none }
	if !praxo.is_object(payload) {
		return none
	}
	if !praxo.get_bool(payload, 'active', false) {
		return none
	}
	subject := praxo.get_string(payload, 'sub') or { return none }
	if subject == '' {
		return none
	}
	tenant := praxo.get_string(payload, authenticator.tenant_claim) or { return none }
	if tenant == '' {
		return none
	}
	exp_value := praxo.get(payload, 'exp') or { return none }
	expires := praxo.as_int(exp_value) or { return none }
	if expires <= now {
		return none
	}
	return Principal{
		subject: subject
		tenant: tenant
		expires: expires
	}
}

fn revoke(client RevocationClient, token string) !bool {
	if token == '' {
		return error('revocation token is required')
	}
	form := {
		'token': token
		'token_type_hint': 'access_token'
		'client_id': client.client_id
		'client_secret': client.client_secret
	}
	response := client.transport(client.endpoint, form,
		basic_auth(client.client_id, client.client_secret)) or {
		return error('token revocation failed')
	}
	if response.status != 200 {
		return error('token revocation failed')
	}
	return true
}
