# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any Elixir HTTP server.

```bash
elixir language/elixir/examples/service/service.exs
```

Expected output:

```text
Elixir service example passed
```

## Authentication

`authentication.ex` adds RFC 7662 introspection and RFC 7009 revocation with a
caller-supplied transport. `HttpTransport` uses `:httpc`. The example remains a
request handler and does not include OIDC/JWKS.

```bash
elixir language/elixir/examples/service/authentication_test.exs
```

Expected output:

```text
Elixir service auth tests passed
```
