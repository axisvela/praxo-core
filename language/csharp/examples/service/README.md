# HTTP Service

This example embeds published NuGet `Praxo.Core==0.11.0` in a standard-library
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

## OIDC/JWKS

Set `PRAXO_OIDC_ISSUER` and `PRAXO_OIDC_AUDIENCE` to verify RS256, RS384, or
RS512 JWTs from an external OIDC provider:

```bash
export PRAXO_OIDC_ISSUER=https://issuer.example.com
export PRAXO_OIDC_AUDIENCE=praxo-service
export PRAXO_OIDC_TENANT_CLAIM=tenant
# optional; discovered from the issuer when omitted
# export PRAXO_OIDC_DISCOVERY_URL=https://issuer.example.com/.well-known/openid-configuration
# export PRAXO_OIDC_JWKS_URL=https://issuer.example.com/.well-known/jwks.json
dotnet run
```

The verifier fetches provider metadata when `PRAXO_OIDC_JWKS_URL` is unset, and
requires the metadata issuer to match the configured issuer. It caches JWKS for
five minutes and refreshes once on an unknown `kid`. It requires a valid
signature, matching `iss` and `aud`, a future integer `exp`, an optional `nbf`
that is not in the future, a non-empty `sub`, and the configured tenant claim.
Discovery, JWKS, timeout, invalid signature, unknown key, wrong issuer, wrong
audience, expired token, or missing claims deny the request. This is not key
management, revocation, or a hosted identity provider.

If both `PRAXO_INTROSPECTION_URL` and `PRAXO_OIDC_ISSUER` are set, introspection
takes precedence.

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
automatically. OIDC/JWKS verification is available separately through
`PRAXO_OIDC_ISSUER`.

## Test

```bash
dotnet run -- --test
```

Expected output:

```text
service test: ok
```

The test uses a fake model, a fake HTTP handler for introspection and
revocation, and a loopback OIDC discovery/JWKS provider. It covers the active
token, inactive token, missing expiration, unavailable provider, revocation
success, revocation failure, OIDC allow, wrong audience, expired token, wrong
issuer, unknown key, and unavailable OIDC provider.
