# Embed Core in an HTTP Service

This tutorial uses the runnable
[`examples/embedded-service`](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service)
project. It shows the minimum shape of a vendor-neutral service: a caller
context enters through HTTP, the application selects the tenant, Core runs the
agent, and the service returns structured output.

## Run

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2

cd examples/embedded-service
go run . -addr :8080 -tenant local
```

Call the service:

```bash
curl -s http://localhost:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

## Python Variant

The Python example uses the same caller-context boundary with the standard
library HTTP server:

```bash
cd language/python/examples/service
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python service.py
```

```bash
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

Run its deterministic tests with:

```bash
.venv/bin/python -m unittest test_service.py -v
```

## Verified Identity Variant

The [authenticated service example](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth)
adds an application-verified HMAC bearer token, subject and tenant claims,
expiration checks, a tenant allowlist before the agent runs, and a file-backed
checkpoint saved on run completion. Set `PRAXO_OIDC_ISSUER` to verify OIDC/JWKS
JWTs instead; the verifier can discover `jwks_uri` from the issuer metadata.

```bash
cd examples/embedded-service-auth
go test ./...
```

The default is an application-local token format, not a general JWT
implementation. Production services should use their identity provider, key
management, audience checks, and revocation.

## Python Authenticated Variant

The [Python authenticated service example](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth)
applies the same boundary with the standard library: HMAC bearer tokens,
subject and tenant claims, expiration checks, a tenant allowlist, policy
binding, and a file-backed checkpoint. Set `PRAXO_POLICY_URL` to delegate
decisions to an application-owned HTTP policy decision service; the example
fails closed on timeout, an invalid response, or a denial. Set
`PRAXO_OIDC_ISSUER` to verify OIDC/JWKS JWTs and discover `jwks_uri` from the
issuer metadata instead of using the local HMAC format.

```bash
cd language/python/examples/service-auth
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt

export PRAXO_SERVICE_SECRET=local-development-secret
.venv/bin/python service.py --addr 127.0.0.1:8080
```

Generate a short-lived token and call the service:

```bash
TOKEN=$(.venv/bin/python service.py --print-token user-1 local --ttl 600)
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"prompt":"What time is it? Use get_time."}'
```

Run its deterministic tests with:

```bash
.venv/bin/python -m unittest test_service.py -v
```

## TypeScript Authenticated Variant

The [TypeScript authenticated service example](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service-auth)
uses Node's standard library with the same HMAC bearer token, tenant allowlist,
policy binding, optional external policy decision service, and file checkpoint.
When `PRAXO_OIDC_ISSUER` is set, it verifies OIDC/JWKS JWTs and can discover
`jwks_uri` from the issuer's `.well-known/openid-configuration`. Set
`PRAXO_INTROSPECTION_URL` to verify opaque tokens through an RFC 7662 endpoint
instead. The example also exposes `node service.js --revoke-token TOKEN` for an
RFC 7009 revocation endpoint and fails closed when a provider endpoint is
unavailable.

```bash
cd language/typescript/examples/service-auth
npm ci

export PRAXO_SERVICE_SECRET=local-development-secret
npm start
```

Generate a token and call the service:

```bash
TOKEN=$(node service.js --print-token user-1 local --ttl 600)
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"prompt":"What time is it? Use get_time."}'
```

Run its deterministic tests with:

```bash
npm test
```

## Other Language Examples

Every declared Core ships a `language/<language>/examples/service` example. The
following table lists the deterministic run command from the repository root.
Go, Python, TypeScript, Java, C#, and Rust include executable HTTP servers; the
remaining examples are transport-neutral request handlers that exercise the same
principal, tenant, `/healthz`, `/run`, and denial checks without opening a socket.
The [language coverage page](../getting-started/language-coverage.md) records
which mode each example uses.

| Language | Run command |
| --- | --- |
| Go | `cd examples/embedded-service && go run . -addr :8080 -tenant local` |
| Python | `cd language/python/examples/service && .venv/bin/python service.py` |
| TypeScript | `cd language/typescript/examples/service && npm start` |
| Java | `cd language/java/examples/service && mvn -q compile exec:java` |
| C# | `cd language/csharp/examples/service && dotnet run` |
| Rust | `cd language/rust/examples/service && cargo run` |
| C | `gcc -std=c11 language/c/examples/service/main.c -o build/c-service && ./build/c-service` |
| C++ | `g++ -std=c++20 language/cpp/examples/service/main.cpp -o build/cpp-service && ./build/cpp-service` |
| COBOL | `python language/cobol/examples/service/build.py` |
| D | `dmd -run language/d/examples/service/service.d` |
| Dart | `dart language/dart/examples/service/service.dart` |
| Delphi / Free Pascal | `fpc -Mobjfpc language/delphi/examples/service/service.pas && ./service` |
| Elixir | `elixir language/elixir/examples/service/service.exs` |
| Erlang | `escript language/erlang/examples/service/service.escript` |
| Fortran | `gfortran language/fortran/examples/service/service_example.f90 -o build/fortran-service && ./build/fortran-service` |
| Haskell | `runghc language/haskell/examples/service/service.hs` |
| Julia | `julia language/julia/examples/service/service.jl` |
| Lua | `lua language/lua/examples/service/service.lua` |
| MATLAB / Octave | `octave-cli --path language/matlab/examples/service --eval service_example` |
| Nim | `nim r language/nim/examples/service/service.nim` |
| Objective-C | `clang -fobjc-arc language/objc/examples/service/service.m -framework Foundation -o build/objc-service && ./build/objc-service` |
| OCaml | `ocaml language/ocaml/examples/service/service.ml` |
| Perl | `perl language/perl/examples/service/service.pl` |
| PHP | `php language/php/examples/service/service.php` |
| PowerShell | `powershell -File language/powershell/examples/service/service.ps1` |
| R | `Rscript language/r/examples/service/service.R` |
| Ruby | `ruby -I language/ruby/lib language/ruby/examples/service/service.rb` |
| Swift | `swift run --package-path language/swift praxo-service-example` |
| V | `v run language/v/examples/service/service.v` |
| Zig | `zig run language/zig/examples/service/service.zig` |

Source-mode handler examples print a language-specific `service example passed`
line and exit nonzero when a denied request reaches the tool. They do not prove
identity verification, durable state, or production HTTP behavior.

## Request Flow

1. The base HTTP handler checks that `X-Praxo-Principal` is present; the
   authenticated variants verify a bearer token and derive the principal.
2. The application selects the tenant and passes both values into the Core
   session.
3. The agent calls the model under an explicit timeout.
4. Policy permits model generation and only the `get_time` tool.
5. The handler returns JSON containing the model output.

`X-Praxo-Principal` is a context stand-in, not authentication. A production
service must verify the caller and derive the principal and tenant from trusted
application state.

## Service Boundary

The base example includes:

- a `/healthz` endpoint;
- `POST /run` with a bounded JSON body;
- HTTP read, write, and idle timeouts;
- a model HTTP timeout;
- SIGINT/SIGTERM shutdown with a bounded drain;
- event logging owned by the application.

The base example deliberately does not include durable sessions, checkpoints,
approvals, or a tenant store. Those are application or product responsibilities.
The authenticated variants add a bounded token check and a file checkpoint.

## Test Without a Model

```bash
cd examples/embedded-service
go test ./...
```

The tests use a fake model and `httptest`, so they do not need an endpoint.

## Next Steps

- Replace the principal header with verified identity.
- Scope checkpoints, events, and tool access by tenant.
- Add a durable checkpoint store for long-running work.
- Put shell, file, and network tools behind application-owned isolation.
- Use the [application integration checklist](application-integration-checklist.md)
  before production.

## Related

- [Application integration checklist](application-integration-checklist.md)
- [Identity and policy](identity-policy.md)
- [Long-running operations](long-running-operations.md)
- [Security model](../security/index.md)
- [Examples](../getting-started/examples.md)
