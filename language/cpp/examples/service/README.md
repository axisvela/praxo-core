# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any C++ HTTP server.

```bash
g++ -std=c++20 language/cpp/examples/service/main.cpp -o build/cpp-service
./build/cpp-service
```

Expected output:

```text
C++ service example passed
```

## Authentication

`authentication.cpp` provides RFC 7662 introspection and RFC 7009 revocation
with a caller-supplied transport. The module publishes `AuthenticatedPrincipal`,
`IntrospectionAuthenticator`, and `RevocationClient`; `authentication_test.cpp`
uses a fake transport. OIDC and JWKS verification are not included.

```bash
g++ -std=c++20 -I language/cpp/include \
  language/cpp/examples/service/authentication.cpp \
  language/cpp/examples/service/authentication_test.cpp \
  -o build/cpp-service-auth
./build/cpp-service-auth
```

Expected output:

```text
C++ service auth tests passed
```
