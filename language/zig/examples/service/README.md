# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

```bash
zig run language/zig/examples/service/service.zig
```

Expected output:

```text
Zig service example passed
```

`authentication.zig` provides RFC 7662 introspection and RFC 7009 revocation
with an injectable transport. The module path is
`language/zig/examples/service/authentication.zig`; tests use a scripted
transport and require no live identity provider.

```bash
zig test language/zig/examples/service/authentication_test.zig
```

If `zig` is not on `PATH`, invoke the installed binary directly.

Expected output:

```text
All 7 tests passed.
```

Introspection requires `active: true`, `sub`, the configured tenant claim, and
a future integer `exp`. Provider errors and failed revocation fail closed. OIDC
and JWKS verification are not included in this Zig example.
