# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any C HTTP server.

```bash
gcc -std=c11 language/c/examples/service/main.c -o build/c-service
./build/c-service
```

Expected output:

```text
C service example passed
```

## Authentication

`authentication.c` provides RFC 7662 introspection and RFC 7009 revocation with
a caller-supplied transport. The module publishes `ServiceAuthPrincipal`,
`ServiceAuthIntrospector`, and `ServiceAuthRevoker`; `authentication_test.c`
uses a fake transport. OIDC and JWKS verification are not included.

```bash
gcc -std=c11 -I language/c/include -I language/c/src \
  language/c/examples/service/authentication.c \
  language/c/examples/service/authentication_test.c \
  language/c/src/json.c -lm -o build/c-service-auth
./build/c-service-auth
```

Expected output:

```text
C service auth tests passed
```
