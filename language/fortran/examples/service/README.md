# HTTP Service

This example defines a transport-neutral request handler boundary with health,
principal, and run cases. Wire it into any Fortran HTTP server.

```bash
gfortran language/fortran/examples/service/service_example.f90 \
  -o build/fortran-service
./build/fortran-service
```

Expected output:

```text
Fortran service example passed
```

`authentication.f90` provides RFC 7662 introspection and RFC 7009 revocation
with an injectable transport. The module path is
`language/fortran/examples/service/authentication.f90`; tests use a scripted
transport and require no live identity provider.

```bash
mkdir -p build/fortran-service
gfortran -std=f2008 -ffree-line-length-none \
  -I build/fortran-service -J build/fortran-service \
  language/fortran/src/praxo_types.f90 \
  language/fortran/src/praxo_unicode.f90 \
  language/fortran/src/praxo_json.f90 \
  language/fortran/examples/service/authentication.f90 \
  language/fortran/examples/service/authentication_test.f90 \
  -o build/fortran-service/authentication_test.exe
./build/fortran-service/authentication_test.exe
```

On Windows, add the MinGW runtime directory to `PATH` before running the test
executable.

Expected output:

```text
Fortran service auth tests passed
```

Introspection requires `active: true`, `sub`, the configured tenant claim, and
a future integer `exp`. Provider errors and failed revocation fail closed. OIDC
and JWKS verification are not included in this Fortran example.
