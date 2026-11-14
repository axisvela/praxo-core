# HTTP Service

This example embeds published crates.io `praxo-core@0.8.0` in a
standard-library TCP/HTTP service. The application supplies a principal and
tenant, restricts tools, and returns JSON.

Rust has no bundled OpenAI-compatible HTTP client in this release. The example
uses a local `Model` implementation so it runs without an endpoint. Wire a
provider adapter behind the same `Model` trait for a real deployment.

## Run

```bash
cargo run
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
cargo run -- --test
```

Expected output:

```text
service test: ok
```

The test calls the request handler directly; no endpoint or socket is required.
