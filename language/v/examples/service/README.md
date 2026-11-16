# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

`language/v/examples/service/authentication.v` provides RFC 7662 token
introspection and RFC 7009 revocation with an injectable transport and a
`Principal` struct. It uses the existing `praxo` JSON helper and
`encoding.base64`.

Run the deterministic authentication tests:

```bash
v -path "language/v|@vlib|@vmodules" test language/v/examples/service
```

Expected result: the V test runner reports no failures.

Verified locally with the existing D:\dev toolchain; the scripted-transport auth test passed.

The existing handler check remains:

```bash
v run language/v/examples/service/service.v
```

Expected output:

```text
V service example passed
```

Introspection requires `active: true`, non-empty `sub`, the configured tenant
claim, and an integer `exp` greater than `now`. Provider errors, malformed JSON,
non-200 responses, and expired tokens fail closed. OIDC and JWKS are not
included.
