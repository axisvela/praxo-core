# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

`authentication.dart` provides RFC 7662 introspection and RFC 7009 revocation
with an injectable transport. `HttpTransport` uses `dart:io`; tests use a
scripted transport. The handler remains transport-neutral, so the application
must authenticate before `handle`.

```bash
dart language/dart/examples/service/service.dart
```

Expected output:

```text
Dart service example passed
Dart service auth tests passed
```

Introspection requires `active: true`, `sub`, the configured tenant claim, and
a future integer `exp`. Provider errors and failed revocation fail closed. OIDC
and JWKS verification are not included in this Dart example.
