# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

`language/nim/examples/service/authentication.nim` provides RFC 7662 token
introspection and RFC 7009 revocation with an injectable transport, a
`Principal` object, and `AuthError`. It uses `std/json` and `std/base64`.

Run the deterministic authentication tests:

```bash
nim r language/nim/examples/service/test_authentication.nim
```

Expected output:

```text
Nim service auth tests passed
```

unverified: toolchain absent

The existing handler check remains:

```bash
nim r language/nim/examples/service/service.nim
```

Expected output:

```text
Nim service example passed
```

Introspection requires `active: true`, non-empty `sub`, the configured tenant
claim, and an integer `exp` greater than `now`. Provider errors, malformed JSON,
non-200 responses, and expired tokens fail closed. OIDC and JWKS are not
included.
