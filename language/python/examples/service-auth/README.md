# Authenticated HTTP Service

This example embeds published PyPI `praxo-core==0.8.1` in a standard-library
HTTP service with application-owned identity, tenant policy, and file-backed
checkpoints.

The service verifies an HMAC bearer token before the agent runs. The token
carries a subject, tenant, and expiration. The application binds the verified
principal to the session, checks the tenant allowlist, authorizes only
`model.generate` and `get_time`, and saves a completed checkpoint after the run.

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
revocation, or key rotation.

## Test

```bash
.venv/bin/python -m unittest test_service.py -v
```

The tests use a fake model and a loopback HTTP server. They cover missing,
tampered, and expired tokens, tenant denial, policy binding, and checkpoint
persistence without an external endpoint.

## Boundaries

- Core does not authenticate callers or issue credentials.
- Replace the local HMAC format with your identity provider, audience checks,
  key management, and revocation in production.
- The checkpoint file is not a transaction or an effect ledger. Scope it by
  tenant and session, and reconcile high-impact side effects separately.
- Shell, file, and network tools need application-owned isolation and
  least-privilege credentials.

## Related

- [Identity and policy](../../../../docs/guides/identity-policy.md)
- [Embed Core in an HTTP service](../../../../docs/guides/embedded-service-tutorial.md)
- [Application integration checklist](../../../../docs/guides/application-integration-checklist.md)
