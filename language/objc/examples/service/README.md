# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

```bash
clang -fobjc-arc language/objc/examples/service/service.m \
  -framework Foundation -o build/objc-service
./build/objc-service
```

Expected output:

```text
Objective-C service example passed
```

## Authentication

`authentication.m` provides RFC 7662 introspection and RFC 7009 revocation with
a caller-supplied transport block. The module publishes
`ServiceAuthPrincipal`, `ServiceAuthIntrospectionAuthenticator`, and
`ServiceAuthRevocationClient`; `authentication_test.m` uses a fake transport.
OIDC and JWKS verification are not included.

On macOS:

```bash
clang -fobjc-arc -fblocks \
  language/objc/examples/service/authentication.m \
  language/objc/examples/service/authentication_test.m \
  -framework Foundation -o build/objc-service-auth
./build/objc-service-auth
```

On GNUstep:

```bash
clang -fobjc-arc -fblocks -fobjc-runtime=gnustep-2.0 -fuse-ld=lld \
  -lgnustep-base -lobjc -lstdc++ \
  language/objc/examples/service/authentication.m \
  language/objc/examples/service/authentication_test.m \
  -o build/objc-service-auth
./build/objc-service-auth
```

Expected output:

```text
Objective-C service auth tests passed
```
