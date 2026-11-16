# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

```bash
fpc -Mobjfpc language/delphi/examples/service/service.pas
./service
```

Expected output:

```text
Delphi service example passed
```

`authentication.pas` provides RFC 7662 introspection and RFC 7009 revocation
with an injectable transport. The module path is
`language/delphi/examples/service/authentication.pas`; tests use a scripted
transport and require no live identity provider.

```bash
mkdir -p build/delphi
fpc -Mobjfpc -Fulanguage/delphi/examples/service -FUbuild/delphi \
  -FEbuild/delphi language/delphi/examples/service/authentication_test.pas
./build/delphi/authentication_test
```

On Windows use `build\delphi\authentication_test.exe`.

Expected output:

```text
Delphi service auth tests passed
```

Introspection requires `active: true`, `sub`, the configured tenant claim, and
a future integer `exp`. Provider errors and failed revocation fail closed. OIDC
and JWKS verification are not included in this Delphi example.
