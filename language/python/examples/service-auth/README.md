# Authenticated HTTP Service

This example embeds published PyPI `praxo-core==0.9.0` in a standard-library
HTTP service with application-owned identity, tenant policy, an optional
external policy decision service, and file-backed checkpoints.

The service verifies an HMAC bearer token before the agent runs, an OIDC/JWKS
JWT when `PRAXO_OIDC_ISSUER` is set, or an opaque token through RFC 7662
introspection when `PRAXO_INTROSPECTION_URL` is set. The token carries a
subject, tenant, and expiration. The application binds the verified principal to
the session, checks the tenant allowlist, authorizes only `model.generate` and
`get_time`, and saves a completed checkpoint after the run.

## Run

```bash
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt

export PRAXO_SERVICE_SECRET=local-development-secret
export PRAXO_ALLOWED_TENANTS=local
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
.venv/bin/python service.py --addr 127.0.0.1:8080
```

Generate a short-lived token and call the service:

```bash
TOKEN=$(.venv/bin/python service.py --print-token user-1 local --ttl 600)
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"prompt":"What time is it? Use get_time."}'
```

The token format is application-local: base64url JSON claims signed with
HMAC-SHA256. It is not a JWT implementation and has no issuer, audience,
revocation, or key rotation. Set `PRAXO_OIDC_ISSUER` to use the OIDC/JWT path
instead.

## OIDC Identity Provider

The service can verify RS256, RS384, and RS512 JWTs from an external OIDC
identity provider:

```bash
export PRAXO_OIDC_ISSUER=https://issuer.example.com
export PRAXO_OIDC_AUDIENCE=praxo-service
# optional; discovered from the issuer when omitted
# export PRAXO_OIDC_DISCOVERY_URL=https://issuer.example.com/.well-known/openid-configuration
# export PRAXO_OIDC_JWKS_URL=https://issuer.example.com/.well-known/jwks.json
export PRAXO_OIDC_TENANT_CLAIM=tenant
export PRAXO_OIDC_TIMEOUT=2
.venv/bin/python service.py --addr 127.0.0.1:8080
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
request. The OIDC path uses only the Python standard library; `--print-token`
remains HMAC-only.

## Token Introspection

Set `PRAXO_INTROSPECTION_URL` to verify opaque access tokens through an
RFC 7662-compatible endpoint:

```bash
export PRAXO_INTROSPECTION_URL=https://issuer.example.com/introspect
export PRAXO_INTROSPECTION_CLIENT_ID=praxo-service
export PRAXO_INTROSPECTION_CLIENT_SECRET=...
export PRAXO_OIDC_TENANT_CLAIM=tenant
.venv/bin/python service.py --addr 127.0.0.1:8080
```

Client credentials use HTTP Basic authentication. When the URL is unset but
`PRAXO_OIDC_ISSUER` is set, the endpoint can be discovered from provider
metadata. The verifier requires `active: true`, `sub`, the configured tenant
claim, and an integer `exp` in the future. A timeout, non-200 response,
inactive token, missing claim, or expired `exp` denies the request. Introspection
takes precedence over OIDC/JWT verification when both are configured.

## Token Revocation

Revoke a token through an RFC 7009-compatible endpoint:

```bash
export PRAXO_REVOCATION_URL=https://issuer.example.com/revoke
export PRAXO_INTROSPECTION_CLIENT_ID=praxo-service
export PRAXO_INTROSPECTION_CLIENT_SECRET=...
.venv/bin/python service.py --revoke-token "$TOKEN"
```

When `PRAXO_REVOCATION_URL` is unset, the endpoint can be discovered from
`PRAXO_OIDC_ISSUER` metadata. Revocation is an application decision; the service
does not revoke automatically on logout, approval, or run completion.

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
.venv/bin/python -m unittest test_service.py -v
```

The tests use a fake model, a loopback HTTP service, a loopback policy decision
service, a loopback OIDC discovery/JWKS endpoint, and a loopback introspection
and revocation endpoint. They cover missing, tampered, and expired HMAC tokens,
OIDC allowed/wrong-audience/expired/unknown-key/unavailable-provider behavior,
introspection active/inactive/unavailable/missing-exp behavior, revocation
success and failure, tenant denial, remote policy allow/deny/unavailable
behavior, policy binding, and checkpoint persistence without a model endpoint.

## Boundaries

- Core does not authenticate callers or issue credentials.
- Replace the local HMAC format with your identity provider, audience checks,
  key management, and revocation in production. The OIDC path verifies JWT
  signatures and standard claims; introspection and revocation are separate
  opt-in paths. The example does not perform token exchange or DPoP.
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
