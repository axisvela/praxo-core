function test_service_auth()
calls = {};
payload = '';
status = 200;
transport_error = false;

auth = praxo_service.introspection_authenticator(@fake_transport, ...
    'https://issuer.example/introspect', ...
    struct('client_id', 'client', 'client_secret', 'secret'));

payload = '{"active":true,"sub":"alice","tenant":"acme","exp":200}';
principal = praxo_service.authenticate(auth, 'Bearer token-1', 100);
assert(~isempty(principal));
assert(strcmp(principal.subject, 'alice'));
assert(strcmp(principal.tenant, 'acme'));
assert(principal.expires == 200);
assert(numel(calls) == 1);
assert(strcmp(calls{1}.url, 'https://issuer.example/introspect'));
assert(strcmp(calls{1}.form.token, 'token-1'));
assert(strcmp(calls{1}.form.client_id, 'client'));
assert(strcmp(calls{1}.form.client_secret, 'secret'));
assert(strcmp(calls{1}.authorization, 'Basic Y2xpZW50OnNlY3JldA=='));

before = numel(calls);
assert(isempty(praxo_service.authenticate(auth, 'Token token-1', 100)));
assert(isempty(praxo_service.authenticate(auth, '', 100)));
assert(isempty(praxo_service.authenticate(auth, 'Bearer    ', 100)));
assert(numel(calls) == before);

payload = '{"active":false,"sub":"alice","tenant":"acme","exp":200}';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = '{"active":"true","sub":"alice","tenant":"acme","exp":200}';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = '{"active":true,"tenant":"acme","exp":200}';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = '{"active":true,"sub":"","tenant":"acme","exp":200}';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = '{"active":true,"sub":"alice","exp":200}';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = '{"active":true,"sub":"alice","tenant":"","exp":200}';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = '{"active":true,"sub":"alice","tenant":"acme"}';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = '{"active":true,"sub":"alice","tenant":"acme","exp":200.5}';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = '{"active":true,"sub":"alice","tenant":"acme","exp":100}';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = 'not json';
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));

payload = '{"active":true,"sub":"alice","tenant":"acme","exp":200}';
status = 401;
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));
status = 200;

transport_error = true;
assert(isempty(praxo_service.authenticate(auth, 'Bearer token-1', 100)));
transport_error = false;

custom = praxo_service.introspection_authenticator(@fake_transport, ...
    'https://issuer.example/introspect', ...
    struct('client_id', 'client', 'client_secret', 'secret', ...
    'tenant_claim', 'workspace'));
payload = '{"active":true,"sub":"alice","workspace":"team-a","exp":200}';
principal = praxo_service.authenticate(custom, 'Bearer token-1', 100);
assert(~isempty(principal));
assert(strcmp(principal.tenant, 'team-a'));

anonymous = praxo_service.introspection_authenticator(@fake_transport, ...
    'https://issuer.example/introspect', struct());
calls = {};
payload = '{"active":true,"sub":"alice","tenant":"acme","exp":200}';
principal = praxo_service.authenticate(anonymous, 'Bearer token-1', 100);
assert(~isempty(principal));
assert(numel(calls) == 1);
assert(isempty(calls{1}.authorization));
assert(strcmp(calls{1}.form.client_id, ''));
assert(strcmp(calls{1}.form.client_secret, ''));

client = praxo_service.revocation_client(@fake_transport, ...
    'https://issuer.example/revoke', ...
    struct('client_id', 'client', 'client_secret', 'secret'));
calls = {};
status = 200;
assert(praxo_service.revoke(client, 'token-2'));
assert(numel(calls) == 1);
assert(strcmp(calls{1}.form.token, 'token-2'));
assert(strcmp(calls{1}.form.token_type_hint, 'access_token'));
assert(strcmp(calls{1}.authorization, 'Basic Y2xpZW50OnNlY3JldA=='));

calls = {};
status = 400;
threw = false;
try
    praxo_service.revoke(client, 'token-2');
catch err
    threw = true;
    assert(strcmp(err.identifier, 'praxo:service'));
end
assert(threw);
assert(numel(calls) == 1);
status = 200;

calls = {};
transport_error = true;
threw = false;
try
    praxo_service.revoke(client, 'token-2');
catch err
    threw = true;
    assert(strcmp(err.identifier, 'praxo:service'));
end
assert(threw);
transport_error = false;

calls = {};
threw = false;
try
    praxo_service.revoke(client, '');
catch err
    threw = true;
    assert(strcmp(err.identifier, 'praxo:service'));
end
assert(threw);
assert(isempty(calls));

anonymous_client = praxo_service.revocation_client(@fake_transport, ...
    'https://issuer.example/revoke', struct());
calls = {};
status = 200;
assert(praxo_service.revoke(anonymous_client, 'token-3'));
assert(isempty(calls{1}.authorization));

disp('test_service_auth passed');

    function response = fake_transport(url, form, authorization)
        calls{end + 1} = struct('url', url, 'form', form, ...
            'authorization', authorization);
        if transport_error
            error('transport:down', 'transport down');
        end
        response = struct('status', status, 'body', payload);
    end
end
