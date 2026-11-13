# HTTP Service

This example embeds published NuGet `Praxo.Core==0.6.0` in a standard-library
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

## Test

```bash
dotnet run -- --test
```

Expected output:

```text
service test: ok
```

The test uses a fake model and calls the request handler directly; no endpoint
or socket is required.
