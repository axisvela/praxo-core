# Embed Core in an HTTP Service

This tutorial uses the runnable
[`examples/embedded-service`](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service)
project. It shows the minimum shape of a vendor-neutral service: a caller
context enters through HTTP, the application selects the tenant, Core runs the
agent, and the service returns structured output.

## Run

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2

cd examples/embedded-service
go run . -addr :8080 -tenant local
```

Call the service:

```bash
curl -s http://localhost:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

## Request Flow

1. The HTTP handler checks that `X-Praxo-Principal` is present.
2. The application selects the tenant and passes both values into the Core
   session.
3. The agent calls the model under an explicit timeout.
4. Policy permits model generation and only the `get_time` tool.
5. The handler returns JSON containing the model output.

`X-Praxo-Principal` is a context stand-in, not authentication. A production
service must verify the caller and derive the principal and tenant from trusted
application state.

## Service Boundary

The example includes:

- a `/healthz` endpoint;
- `POST /run` with a bounded JSON body;
- HTTP read, write, and idle timeouts;
- a model HTTP timeout;
- SIGINT/SIGTERM shutdown with a bounded drain;
- event logging owned by the application.

It deliberately does not include durable sessions, checkpoints, approvals, or a
tenant store. Those are application or product responsibilities.

## Test Without a Model

```bash
cd examples/embedded-service
go test ./...
```

The tests use a fake model and `httptest`, so they do not need an endpoint.

## Next Steps

- Replace the principal header with verified identity.
- Scope checkpoints, events, and tool access by tenant.
- Add a durable checkpoint store for long-running work.
- Put shell, file, and network tools behind application-owned isolation.
- Use the [application integration checklist](application-integration-checklist.md)
  before production.

## Related

- [Application integration checklist](application-integration-checklist.md)
- [Identity and policy](identity-policy.md)
- [Long-running operations](long-running-operations.md)
- [Security model](../security/index.md)
- [Examples](../getting-started/examples.md)
