# HTTP Service

This example embeds published npm `@axisvela/praxo-core@0.5.0` in a Node
standard-library HTTP service. The application supplies a principal and tenant,
restricts tools, and returns JSON.

## Run

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
npm install
npm start
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
npm test
```

The test uses a fake model and a loopback HTTP server; no endpoint is required.
It covers health, missing principal, and a successful run.
