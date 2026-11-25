# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

`authentication.swift` provides RFC 7662 introspection and RFC 7009 revocation
with an injectable transport. `URLSessionTransport` uses Foundation with a
two-second timeout; tests use a scripted transport. Module entry point is
`language/go/examples/service/main.swift`; `authentication.swift` holds the authentication
types. The handler remains transport-neutral, so the application must
authenticate before `handle`.

```bash
swift run --package-path language/swift praxo-service-example
```

Expected output:

```text
Swift service example passed
Swift service auth tests passed
```

Introspection requires `active: true`, `sub`, the configured tenant claim, and
a future integer `exp`. Provider errors and failed revocation fail closed. OIDC
and JWKS verification are not included in this Swift example.

Verified at runtime on Windows with `swiftc -use-ld=lld` plus the assembled
Windows SDK and MSVC CRT libraries; the executable prints both expected lines.
`swift build` remains blocked by the local toolchain, so the documented link/run
command is the local gate. macOS CI remains authoritative.
