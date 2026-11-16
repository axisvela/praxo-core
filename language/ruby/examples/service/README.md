# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any Ruby HTTP server.

`authentication.rb` provides RFC 7662 introspection and RFC 7009 revocation
with an injectable transport. `NetHttpTransport` is the standard-library
implementation; tests use a scripted transport. The handler remains
transport-neutral, so the application must place authentication before
`ServiceExample.handle`.

```bash
ruby language/ruby/examples/service/service.rb
```

Expected output:

```text
Ruby service example passed
Ruby service auth tests passed
```

Introspection requires `active: true`, `sub`, the configured tenant claim, and
a future integer `exp`. Provider errors and failed revocation fail closed. OIDC
and JWKS verification are not included in this Ruby example.
