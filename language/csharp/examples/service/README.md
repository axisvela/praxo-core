# HTTP Service

This example embeds published NuGet `Praxo.Core==0.9.2` in a standard-library
TCP/HTTP service. The application supplies a principal and tenant, restricts
tools, and returns JSON.

## Run

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
dotnet run
```

```bash
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

The `X-Praxo-Principal` header is an application context stand-in, not
authentication. A production service must verify identity and derive the
principal and tenant from trusted context.

## Token Introspection

Set `PRAXO_INTROSPECTION_URL` to verify `Authorization: Bearer` tokens through
an RFC 7662 endpoint:

```bash
export PRAXO_INTROSPECTION_URL=https://issuer.example.com/introspect
export PRAXO_INTROSPECTION_CLIENT_ID=praxo-service
export PRAXO_INTROSPECTION_CLIENT_SECRET=...
export PRAXO_OIDC_TENANT_CLAIM=tenant
dotnet run
```

```bash
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer opaque-token' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

The verifier requires `active: true`, `sub`, the configured tenant claim, and an
integer `exp` in the future. A timeout, non-200 response, inactive token,
missing claim, or expired `exp` denies the request.

## Token Revocation

```bash
export PRAXO_REVOCATION_URL=https://issuer.example.com/revoke
export PRAXO_INTROSPECTION_CLIENT_ID=praxo-service
export PRAXO_INTROSPECTION_CLIENT_SECRET=...
dotnet run -- --revoke-token "$TOKEN"
```

Revocation is an application decision; the service does not revoke
automatically. OIDC/JWKS verification is not included in this C# service
example.

## Test

```bash
dotnet run -- --test
```

Expected output:

```text
service test: ok
```

The test uses a fake model, a fake HTTP handler for introspection and
revocation, and calls the request handler directly; no endpoint, socket, or
identity provider is required. It covers the active token, inactive token,
missing expiration, unavailable provider, revocation success, and revocation
failure.
