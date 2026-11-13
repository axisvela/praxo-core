# Embedded HTTP Service

This example embeds PRAXO-CORE in a vendor-neutral HTTP service using the
published `github.com/axisvela/praxo-core/v2` module.

It shows:

- application-selected tenant and caller context;
- explicit policy and tool allowlist;
- model request timeout;
- HTTP read/write/idle timeouts;
- health endpoint and graceful shutdown;
- event forwarding to the application log.

## Run

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
go run . -addr :8080 -tenant local
```

```bash
curl -s http://localhost:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

The `X-Praxo-Principal` header is an application-supplied context stand-in. It is
not authentication. A production service must verify identity and derive the
principal and tenant from trusted context.

## Test

```bash
go test ./...
```

The tests use a fake model and `httptest`; they do not require an endpoint.
