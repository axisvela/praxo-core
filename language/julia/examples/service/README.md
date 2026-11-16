# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

`language/julia/examples/service/authentication.jl` provides RFC 7662 token
introspection and RFC 7009 revocation with an injectable transport, a
`Principal` struct, and an `AuthError`. It loads the Core JSON helper from
`language/julia/src/Json.jl`.

Run the deterministic authentication tests:

```bash
julia --project=language/julia language/julia/examples/service/test_authentication.jl
```

Expected output:

```text
Julia service auth tests passed
```

Verified locally with the existing D:\dev toolchain; the scripted-transport auth test passed.

The existing handler check remains:

```bash
julia language/julia/examples/service/service.jl
```

Expected output:

```text
Julia service example passed
```

Introspection requires `active: true`, non-empty `sub`, the configured tenant
claim, and an integer `exp` greater than `now`. Provider errors, malformed JSON,
non-200 responses, and expired tokens fail closed. OIDC and JWKS are not
included.
