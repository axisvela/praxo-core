# HTTP Service

This example embeds published crates.io `praxo-core@0.10.0` in a
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

`src/authentication.rs` provides RFC 7662 introspection and RFC 7009
revocation with a caller-supplied `Transport` trait. It verifies
`Authorization: Bearer` tokens, requires `active`, non-empty `sub` and tenant
claims, and a future integer `exp`, and fails closed when the provider is
unavailable. Revocation is an explicit application decision.

The example does not bundle an HTTP or TLS client; a production application
supplies the transport, for example `ureq` or a product HTTP client.

```bash
cargo test
```

Expected output includes:

```text
test authentication::tests::authentication_contract ... ok
```

## Test

```bash
cargo run -- --test
```

Expected output:

```text
service test: ok
```

The test calls the request handler directly; no endpoint or socket is required.
