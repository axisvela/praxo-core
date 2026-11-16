# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any PHP HTTP server.

`authentication.php` provides RFC 7662 introspection and RFC 7009 revocation
with an injectable transport. `StreamTransport` uses PHP's HTTP stream wrapper;
tests use a scripted transport. The handler remains transport-neutral, so the
application must place authentication before `handleRequest`.

```bash
php language/php/examples/service/service.php
```

Expected output:

```text
PHP service example passed
PHP service auth tests passed
```

Introspection requires `active: true`, `sub`, the configured tenant claim, and
a future integer `exp`. Provider errors and failed revocation fail closed. OIDC
and JWKS verification are not included in this PHP example.
