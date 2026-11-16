# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any Lua HTTP server.

```bash
lua language/lua/examples/service/service.lua
```

Expected output:

```text
Lua service example passed
```

## Authentication

`language/lua/examples/service/authentication.lua` returns
`ContextAuthenticator`, `IntrospectionAuthenticator`, `RevocationClient`, and
`Principal`. RFC 7662 introspection and RFC 7009 revocation use a
caller-supplied transport; Lua has no built-in HTTP client, so no network
dependency is added. Introspection requires `active: true`, a non-empty `sub`,
the configured tenant claim, and a future integer `exp`. Provider errors,
malformed bodies, non-200 responses, and failed revocation fail closed. OIDC and
JWKS verification are not included.

```bash
lua language/lua/examples/service/authentication_test.lua
```

Expected output:

```text
Lua service auth tests passed
```
