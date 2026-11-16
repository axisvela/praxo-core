# HTTP Service

This example embeds published crates.io `praxo-core@0.9.1` in a
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

## Token Introspection and Revocation

This example does not bundle an HTTP or TLS client, so RFC 7662 introspection
and RFC 7009 revocation are not enabled by default. A production application
should supply its own transport (for example `ureq` or a product HTTP client),
verify `Authorization: Bearer` tokens, require `active`, `sub`, the tenant
claim, and a future `exp`, and fail closed when the provider is unavailable.
Keep revocation an explicit application decision.

The Go, Python, TypeScript, Java, and C# service-auth examples show the same
contract with their standard-library HTTP clients.

## Test

```bash
cargo run -- --test
```

Expected output:

```text
service test: ok
```

The test calls the request handler directly; no endpoint or socket is required.
