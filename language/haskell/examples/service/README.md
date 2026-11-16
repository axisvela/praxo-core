# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

`authentication.hs` is the `Authentication` module and provides RFC 7662
introspection and RFC 7009 revocation with an injectable transport. The module
reuses `Praxo.Json`, so it must be loaded with `-ilanguage/haskell/src`. Tests
use a scripted transport. The handler remains transport-neutral, so the
application must authenticate before `handle`.

```bash
runghc language/haskell/examples/service/service.hs
runghc -ilanguage/haskell/src -ilanguage/haskell/examples/service language/haskell/examples/service/authentication_test.hs
```

Expected output:

```text
Haskell service example passed
Haskell service auth tests passed
```

Introspection requires `active: true`, `sub`, the configured tenant claim, and
a future integer `exp`. Provider errors and failed revocation fail closed. OIDC
and JWKS verification are not included in this Haskell example.

Verified locally with GHC 9.12.2 (`runghc`); the scripted-transport auth test
prints `Haskell service auth tests passed`.
