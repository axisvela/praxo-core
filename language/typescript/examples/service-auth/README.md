# Authenticated HTTP Service

This example embeds published npm `@axisvela/praxo-core@0.8.0` in a Node
standard-library HTTP service with application-owned identity (local HMAC or
OIDC), tenant policy, an optional external policy decision service, and
file-backed checkpoints.

The service verifies a bearer identity before the agent runs. The verified
principal carries a subject, tenant, and expiration. The application binds the
principal to the session, checks the tenant allowlist, authorizes only
`model.generate` and `get_time`, and saves a completed checkpoint after the run.

## Run

```bash
npm ci

export PRAXO_SERVICE_SECRET=local-development-secret
export PRAXO_ALLOWED_TENANTS=local
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
npm start
```

`PRAXO_SERVICE_SECRET` selects the local HMAC mode. Set the OIDC variables
below to use an external identity provider instead.

Generate a short-lived token and call the service:

```bash
TOKEN=$(node service.js --print-token user-1 local --ttl 600)
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"prompt":"What time is it? Use get_time."}'
```

The token format is application-local: base64url JSON claims signed with
HMAC-SHA256. It is not a JWT implementation and has no issuer, audience,
revocation, or key rotation. Set `PRAXO_OIDC_ISSUER` to use an OIDC/JWT
verifier instead.

## OIDC Identity Provider

The service can verify JWTs from an external OIDC identity provider:

```bash
export PRAXO_OIDC_ISSUER=https://issuer.example.com
export PRAXO_OIDC_AUDIENCE=praxo-service
export PRAXO_OIDC_JWKS_URL=https://issuer.example.com/.well-known/jwks.json
export PRAXO_OIDC_TENANT_CLAIM=tenant
export PRAXO_OIDC_TIMEOUT=2
npm start
```

The verifier accepts `RS256`, `RS384`, and `RS512`, selects the key by `kid`
from the JWKS, and checks `iss`, `aud`, `exp`, and optional `nbf`. It reads the
subject from `sub` and the tenant from `PRAXO_OIDC_TENANT_CLAIM` (default
`tenant`).

The verifier caches JWKS for five minutes and refreshes once when the token
`kid` is unknown. A missing or invalid signature, unknown `kid`, unavailable
JWKS, invalid issuer or audience, expired token, or missing subject or tenant
denies the request. `--print-token` remains HMAC-only.

## External Policy Decision Service

Set `PRAXO_POLICY_URL` to delegate each `model.generate` and `tool.invoke`
decision to an application-owned HTTP policy decision service after the local
identity and tenant checks:

```bash
export PRAXO_POLICY_URL=https://policy.example.com/authorize
export PRAXO_POLICY_TIMEOUT=2
```

The service sends:

```json
{
  "principal": {"subject": "user-1", "tenant": "local"},
  "action": {
    "kind": "tool.invoke",
    "tool_name": "get_time",
    "arguments": {}
  }
}
```

The policy service must return HTTP 200 with:

```json
{"allowed": true, "reason": "verified operator"}
```

A timeout, non-200 response, invalid body, or denial blocks the run. The local
`get_time` scope is still enforced after an allow, so the external service
cannot widen tool access. If `PRAXO_POLICY_URL` is unset, the local policy is
used. Use a trusted HTTPS endpoint and redact sensitive tool arguments before
sending them to the policy service.

## Test

```bash
npm test
```

The tests use a fake model, a loopback HTTP service, a loopback policy decision
service, and a generated RSA key with a loopback JWKS endpoint. They cover
missing, tampered, and expired tokens, OIDC issuer/audience/tenant/signature/
JWKS failures, tenant denial, remote policy allow/deny/unavailable behavior,
policy binding, and checkpoint persistence without a model endpoint.

## Boundaries

- Core does not authenticate callers or issue credentials.
- Replace the local HMAC format with your identity provider, audience checks,
  key management, and revocation in production.
- The OIDC path verifies JWT signatures and standard claims only. It does not
  perform token introspection, revocation, token exchange, DPoP, authorization
  policy, or provider discovery. Use a trusted HTTPS issuer and JWKS endpoint.
- A policy service allow does not replace local tool scope, sandboxing, or
  least-privilege credentials.
- The external policy service receives tool arguments. Send only what the
  decision requires, and use a trusted HTTPS endpoint.
- The checkpoint file is not a transaction or an effect ledger. Scope it by
  tenant and session, and reconcile high-impact side effects separately.
- Shell, file, and network tools need application-owned isolation and
  least-privilege credentials.

## Related

- [Identity and policy](../../../../docs/guides/identity-policy.md)
- [Embed Core in an HTTP service](../../../../docs/guides/embedded-service-tutorial.md)
- [Application integration checklist](../../../../docs/guides/application-integration-checklist.md)
