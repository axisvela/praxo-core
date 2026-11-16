# HTTP Service

This example defines a transport-neutral request handler with health, principal,
and run cases.

`authentication.ml` provides RFC 7662 introspection and RFC 7009 revocation with
an injectable transport and loads the repository JSON helper through
`praxo_core.ml`. Tests use a scripted transport. The handler remains
transport-neutral, so the application must authenticate before `handle`.

```bash
ocaml language/ocaml/examples/service/service.ml
ocaml -I language/ocaml -I language/ocaml/examples/service language/ocaml/examples/service/authentication_test.ml
```

Expected output:

```text
OCaml service example passed
OCaml service auth tests passed
```

Introspection requires `active: true`, `sub`, the configured tenant claim, and
a future integer `exp`. Provider errors and failed revocation fail closed. OIDC
and JWKS verification are not included in this OCaml example.

Local status: unverified because OCaml is not installed on the local
workstation. The source and tests are provided but were not compiled or run.
