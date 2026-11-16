# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any R HTTP server.

`language/r/examples/service/authentication.R` provides RFC 7662 token
introspection and RFC 7009 revocation with an injectable transport, a principal
list, and a `service_auth_error` condition. It uses the existing Core JSON
helper in `language/r/R/json.R`; source that file before `authentication.R`.

Run the deterministic authentication tests:

```bash
Rscript language/r/examples/service/test_authentication.R
```

Expected output:

```text
R service auth tests passed
```

Verified locally with the existing D:\dev toolchain; the scripted-transport auth test passed.

The existing handler check remains:

```bash
Rscript language/r/examples/service/service.R
```

Expected output:

```text
R service example passed
```

Introspection requires `active: true`, non-empty `sub`, the configured tenant
claim, and an integer `exp` greater than `now`. Provider errors, malformed JSON,
non-200 responses, and expired tokens fail closed. OIDC and JWKS are not
included.
