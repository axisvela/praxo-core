# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

`authentication.swift` provides RFC 7662 introspection and RFC 7009 revocation
with an injectable transport. `URLSessionTransport` uses Foundation with a
two-second timeout; tests use a scripted transport. Module entry point is
`examples/service/main.swift`; `authentication.swift` holds the authentication
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

Local status: unverified at runtime because `swift build` is blocked by the
Windows toolchain. Source may be checked with `swiftc -typecheck`; no run is
claimed.
