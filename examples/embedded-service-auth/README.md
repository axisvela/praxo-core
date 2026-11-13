# Authenticated HTTP Service

This example extends the embedded HTTP service with an application-verified
bearer token and tenant-scoped policy.

It demonstrates:

- HMAC-SHA256 token verification in the application;
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

The token format in this example is application-local:

```text
base64url({"sub":"user-1","tenant":"local","exp":...}).hexhmac
```

It is not a general JWT implementation. A production service should use its
identity provider, key management, revocation, and audience checks.

## Test

```bash
go test ./...
```

Tests cover missing token, expired token, unknown tenant, the allowed path, and
checkpoint persistence using a fake model. The file store is a teaching
implementation, not a concurrent database or a power-loss-proof store.
