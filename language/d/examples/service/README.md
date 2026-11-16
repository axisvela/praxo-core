# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

```bash
dmd -run language/d/examples/service/service.d
```

Expected output:

```text
D service example passed
```

## Authentication

`language/d/examples/service/authentication.d` provides
`ContextAuthenticator`, `IntrospectionAuthenticator`, `RevocationClient`, and
`Principal`. RFC 7662 introspection and RFC 7009 revocation use a
caller-supplied transport; the module adds no HTTP dependency. It uses Phobos
`std.json` and `std.base64`. Introspection requires `active: true`, a non-empty
`sub`, the configured tenant claim, and a future integer `exp`. Provider errors,
malformed bodies, non-200 responses, and failed revocation fail closed. OIDC and
JWKS verification are not included.

```bash
dmd -i -Ilanguage/d/examples/service -run language/d/examples/service/authentication_test.d
```

Expected output:

```text
D service auth tests passed
```
