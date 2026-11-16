# Authenticated HTTP Service

This example extends the embedded HTTP service with an application-verified
bearer token and tenant-scoped policy.

It demonstrates:

- HMAC-SHA256 token verification in the application;
- OIDC/JWT verification with provider discovery and JWKS;
- RFC 7662 token introspection and RFC 7009 revocation;
- subject and tenant claims;
- expiration checks;
- tenant allowlist enforcement before the agent runs;
- tenant-scoped policy inside the agent;
- a file-backed checkpoint saved on run completion;
- deterministic `httptest` coverage, including checkpoint persistence.

## Run

```bash
export PRAXO_SERVICE_SECRET=dev-secret
export PRAXO_ALLOWED_TENANTS=local
export PRAXO_CHECKPOINT_DIR=checkpoints
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
go run . -addr :8080
```

For the full file-store contract and its tests, see
[`examples/recipes/checkpoint-store-go`](../recipes/checkpoint-store-go). This
service keeps a smaller store to show the `OnRunComplete` integration.
See also [`examples/recipes/identity-go`](../recipes/identity-go) for the
policy-only identity pattern.

The token format in this example is application-local:

```text
base64url({"sub":"user-1","tenant":"local","exp":...}).hexhmac
```

It is not a general JWT implementation. A production service should use its
identity provider, key management, revocation, and audience checks.

## OIDC Identity Provider

Set `PRAXO_OIDC_ISSUER` to verify RS256, RS384, or RS512 JWTs from an external
identity provider instead of the local HMAC format:

```bash
export PRAXO_OIDC_ISSUER=https://issuer.example.com
export PRAXO_OIDC_AUDIENCE=praxo-service
# optional; discovered from the issuer when omitted
# export PRAXO_OIDC_DISCOVERY_URL=https://issuer.example.com/.well-known/openid-configuration
# export PRAXO_OIDC_JWKS_URL=https://issuer.example.com/.well-known/jwks.json
export PRAXO_OIDC_TENANT_CLAIM=tenant
export PRAXO_OIDC_TIMEOUT=2
go run . -addr :8080
```

When `PRAXO_OIDC_JWKS_URL` is unset, the verifier fetches the issuer's
`.well-known/openid-configuration` metadata and uses its `jwks_uri`. Set
`PRAXO_OIDC_DISCOVERY_URL` only when the metadata document is not at the
standard location. Provider metadata must report the configured issuer.

The verifier checks `iss`, `aud`, `exp`, and optional `nbf`, selects the key by
`kid`, and reads the subject from `sub` and the tenant from
`PRAXO_OIDC_TENANT_CLAIM` (default `tenant`). It caches JWKS for five minutes
and refreshes once when the token `kid` is unknown. A missing or invalid
signature, unknown `kid`, unavailable JWKS or discovery metadata, invalid
issuer or audience, expired token, or missing subject or tenant denies the
request.

## Token Introspection

Set `PRAXO_INTROSPECTION_URL` to verify opaque tokens through an RFC 7662
endpoint:

```bash
export PRAXO_INTROSPECTION_URL=https://issuer.example.com/introspect
export PRAXO_INTROSPECTION_CLIENT_ID=praxo-service
export PRAXO_INTROSPECTION_CLIENT_SECRET=...
export PRAXO_OIDC_TENANT_CLAIM=tenant
go run . -addr :8080
```

Client credentials use HTTP Basic authentication. When the URL is unset but
`PRAXO_OIDC_ISSUER` is set, the endpoint can be discovered from provider
metadata. The verifier requires `active: true`, `sub`, the configured tenant
claim, and an integer `exp` in the future. A timeout, non-200 response, inactive
token, missing claim, or expired `exp` denies the request. Introspection takes
precedence over OIDC/JWT verification when both are configured.

## Token Revocation

Revoke a token through an RFC 7009 endpoint:

```bash
export PRAXO_REVOCATION_URL=https://issuer.example.com/revoke
export PRAXO_INTROSPECTION_CLIENT_ID=praxo-service
export PRAXO_INTROSPECTION_CLIENT_SECRET=...
go run . --revoke-token "$TOKEN"
```

When `PRAXO_REVOCATION_URL` is unset, the endpoint can be discovered from
`PRAXO_OIDC_ISSUER` metadata. Revocation is an application decision; the service
does not revoke automatically on logout, approval, or run completion. Token
exchange, DPoP, and authorization policy remain outside this example.

## Test

```bash
go test ./...
```

Tests cover missing token, expired token, unknown tenant, the allowed path, and
checkpoint persistence using a fake model. OIDC tests use a generated RSA key,
a loopback discovery document, and a loopback JWKS endpoint; they cover the
allowed path, wrong audience, expired token, unknown key, and unavailable
provider metadata. Introspection tests use a loopback RFC 7662 endpoint for
active, inactive, missing-expiration, and unavailable-provider cases;
revocation tests cover success and provider failure. The file store is a
teaching implementation, not a concurrent database or a power-loss-proof store.
