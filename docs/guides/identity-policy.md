# Bind Verified Identity and Policy

This recipe shows an application-level pattern for using a verified principal in
Core authorization. Core provides the authorization hook and final-operation
recheck; the application must authenticate the caller, bind the tenant and
resource, and fail closed.

It is not an identity provider, policy decision service, durable approval store,
or an exactly-once effect mechanism.

## Pattern

1. **Authenticate outside Core.** Verify the caller with your identity system
   and produce a principal containing actor ID, tenant, role, and expiry.
2. **Put only verified data in the context.** Never read the actor ID or role
   from model output or tool arguments.
3. **Authorize in the hook.** Reject a missing, expired, or malformed principal;
   check role, tenant, resource, tool name, and arguments.
4. **Recheck the final operation.** Middleware or approval edits can change the
   tool name or arguments; Core authorizes the final values again.
5. **Fail closed.** If required identity or policy infrastructure is unavailable,
   return an error; do not permit execution.

## Tested Example

The runnable example is the separate L4 recipe module
[`examples/recipes/identity-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/identity-go).
From that directory:

```sh
GOWORK=off go test -mod=readonly -run Identity -v ./...
```

| Check | Expected outcome |
| --- | --- |
| Missing verified principal | denied; zero tool effects |
| Expired principal | denied; zero tool effects |
| Tenant mismatch | denied; zero tool effects |
| Model claims an admin role | ignored; denied; zero tool effects |
| Verified operator for the matching tenant | allowed once |

The recipe stores the principal in a context value after authentication. In a
real service, that value must come from your verified request context or identity
middleware, not from the prompt or model.

The Go authenticated service example
[`examples/embedded-service-auth`](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth)
shows the same binding at a service boundary. It verifies an application-local
HMAC token by default and can verify OIDC/JWKS JWTs with provider discovery when
`PRAXO_OIDC_ISSUER` is set.

The Python authenticated HTTP service
[`language/python/examples/service-auth`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth)
shows the same binding at a service boundary. It verifies an application-local
HMAC bearer token or an OIDC/JWKS JWT, binds the subject and tenant to the
session, rejects expired or disallowed tenants, authorizes only `get_time`, and
saves a completed checkpoint. It can also delegate decisions to an
application-owned HTTP policy decision service and fails closed when that
service is unavailable. Run its deterministic tests with:

```bash
cd language/python/examples/service-auth
python -m unittest test_service.py -v
```

The TypeScript service example
[`language/typescript/examples/service-auth`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service-auth)
applies the same HMAC identity, tenant allowlist, optional external policy
decision service, and checkpoint pattern with Node's standard library. It can
also verify OIDC/JWKS JWTs, discover provider metadata, introspect opaque
tokens, and revoke tokens through application-owned provider endpoints.

## All-Language Examples

Every declared Core ships a `language/<language>/examples/identity-policy`
example. Each one binds a trusted principal, rejects missing, inactive,
role-mismatched, and tenant-mismatched actions, and verifies that denied calls
never invoke the tool. Run these from the repository root.

| Language | Run command |
| --- | --- |
| Go | `cd examples/recipes/identity-go && GOWORK=off go test -mod=readonly -run Identity -v ./...` |
| Python | `cd language/python/examples/identity-policy && .venv/bin/python -m unittest test_identity_policy.py -v` |
| TypeScript | `cd language/typescript/examples/identity-policy && npm test` |
| Java | `cd language/java/examples/identity-policy && mvn -q compile exec:java` |
| C# | `cd language/csharp/examples/identity-policy && dotnet run -- --test` |
| Rust | `cd language/rust/examples/identity-policy && cargo run` |
| C | `gcc -std=c11 -I language/c/include language/c/examples/identity-policy/main.c language/c/build/libpraxo_core.a -o build/c-identity-policy && ./build/c-identity-policy` |
| C++ | `g++ -std=c++20 -I language/cpp/include language/cpp/examples/identity-policy/main.cpp language/cpp/build/libpraxo_cpp.a -o build/cpp-identity-policy && ./build/cpp-identity-policy` |
| COBOL | `python language/cobol/examples/identity-policy/build.py` |
| D | `dmd -run language/d/examples/identity-policy/identity_policy.d` |
| Dart | `dart language/dart/examples/identity-policy/identity_policy.dart` |
| Delphi / Free Pascal | `fpc -Mobjfpc language/delphi/examples/identity-policy/identity_policy.pas && ./identity_policy` |
| Elixir | `elixir language/elixir/examples/identity-policy/identity_policy.exs` |
| Erlang | `escript language/erlang/examples/identity-policy/identity_policy.escript` |
| Fortran | `gfortran language/fortran/examples/identity-policy/identity_policy_example.f90 -o build/fortran-identity-policy && ./build/fortran-identity-policy` |
| Haskell | `runghc language/haskell/examples/identity-policy/identity_policy.hs` |
| Julia | `julia language/julia/examples/identity-policy/identity_policy.jl` |
| Lua | `lua language/lua/examples/identity-policy/identity_policy.lua` |
| MATLAB / Octave | `octave-cli --path language/matlab/examples/identity-policy --eval identity_policy_example` |
| Nim | `nim r language/nim/examples/identity-policy/identity_policy.nim` |
| Objective-C | `clang -fobjc-arc language/objc/examples/identity-policy/identity_policy.m -framework Foundation -o build/objc-identity-policy && ./build/objc-identity-policy` |
| OCaml | `ocaml language/ocaml/examples/identity-policy/identity_policy.ml` |
| Perl | `perl language/perl/examples/identity-policy/identity_policy.pl` |
| PHP | `php language/php/examples/identity-policy/identity_policy.php` |
| PowerShell | `powershell -File language/powershell/examples/identity-policy/identity_policy.ps1` |
| R | `Rscript language/r/examples/identity-policy/identity_policy.R` |
| Ruby | `ruby -I language/ruby/lib language/ruby/examples/identity-policy/identity_policy.rb` |
| Swift | `swift run --package-path language/swift praxo-identity-policy-example` |
| V | `v run language/v/examples/identity-policy/identity_policy.v` |
| Zig | `zig run language/zig/examples/identity-policy/identity_policy.zig` |

These are authorization-pattern examples, not identity providers or policy
decision services. Use the [embedded service tutorial](embedded-service-tutorial.md)
for a service boundary that also verifies tokens.

## Important Limits

- A role string in tool arguments is untrusted input. The hook must use the
  verified principal.
- Identity authorization does not replace sandboxing, least-privilege
  credentials, network controls, or real-time safety.
- An approval decision is not a durable approval store; define binding, expiry,
  revocation, and audit in the application.
- A successful tool call is not proof of a committed external effect. Use an
  effect ledger or reconciliation for high-impact operations.

See the [security model](../security/index.md), [governed execution design](../reference/governed-execution.md),
and [adoption guide](../getting-started/adoption.md).
