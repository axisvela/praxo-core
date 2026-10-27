# AGENTS.md

Guidance for coding agents working in PRAXO-CORE (MIT, public).

## Purpose

PRAXO-CORE is the reusable agent framework behind PRAXOVELA. It is not the
PRAXOVELA product. COORDIVELA is an independent product and does not consume
this framework.

## Documentation Location

- Public framework documents: `docs/` in this repository.
- Internal extraction plan, source mapping, product-family sequencing, and
  PRAXOVELA split decisions: `PRAXOVELA-EE/docs/praxo-core/`.
- COORDIVELA documents: `COORDIVELA/docs/` and `COORDIVELA-ee/docs/`.
- Do not add product-family planning or enterprise-only material to this public
  repository.
- Internal execution plans, estimates, staffing, and release-operator procedures
  belong in `PRAXOVELA-EE/docs/praxo-core/`, even when excluded from site navigation.
- Group public docs by user task and mirror translated paths under `docs/zh-CN/`.
- Preserve published URLs through `scripts/docs_hooks.py` redirects when moving pages.

## Guardrails

- Keep the public API small and documented.
- Do not import AGPL-only packages; this repository must remain MIT.
- Do not copy third-party code without compatible licensing and notices.
- Keep provider credentials, tenant data, and secrets outside the framework.
- Do not commit non-public email domains or `.internal` hostnames;
  `internal/spec/privacy_test.go` enforces the working-tree allowlist.
- Preserve provenance in `docs/project/provenance.md`.
- Add tests for every exported interface and loop behavior.
- Prefer interfaces over concrete integrations.
- Keep source files under 500 lines; split by responsibility instead of growing
  a single file.
- Do not add code comments unless asked.

## Language Implementations

- `spec/` is the normative contract for the Python, TypeScript, and Java SDKs.
- Go remains the reference implementation; do not widen the `pkg/...` API for an
  SDK.
- Keep independent implementations under `sdk/`, bridge wrappers under
  `bindings/`, and shared-runtime language samples under `examples/`.
- Framework is the default target for native-capable languages. Wire is an
  intermediate stage; final wire-only scope requires documented technical
  limitations. Keep current capability claims separate from that target.
- A wire change (JSON field, event, stream kind, plugin envelope, error code)
  must update `spec/` and is breaking for every SDK.
- Add a parity row for every new contract symbol: `spec/parity.md` for the
  original core SDKs, `spec/parity/<language>.md` for newer SDKs.
- An SDK change is done only when its conformance vectors and parity linter
  pass.
- Keep every SDK MIT; review dependency licenses before adopting one.
- See `docs/contributing/sdk-design.md` and `docs/languages/support.md`.
- New languages follow the tier model in `docs/contributing/language-policy.md`; do
  not hand-write a new agent loop without a named consumer.

## Build And Test

```bash
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
cd sdk/python; python conformance/run.py
cd sdk/python; python api-snapshot.py --check
cd sdk/python; python -m unittest discover -s tests -v
cd sdk/typescript; npm ci
cd sdk/typescript; npm run build
cd sdk/typescript; npm run api:check
cd sdk/typescript; npm run conformance
cd sdk/typescript; node --test tests/sdk.test.js tests/openaicompat.test.js
cd sdk/java; mvn -q -DskipTests test-compile
cd sdk/java; mvn -q -DskipTests package
cd sdk/java; java -cp target/classes io.axisvela.praxo.conformance.ApiSnapshot --check
cd sdk/java; java -cp target/classes io.axisvela.praxo.conformance.Run
cd sdk/java; java --add-modules jdk.httpserver -cp target/classes:target/test-classes io.axisvela.praxo.adapters.OpenAICompatibleSelfTest
cd sdk/java; java -cp target/classes:target/test-classes io.axisvela.praxo.agent.AgentConcurrencySelfTest
cd sdk/rust; cargo test
cd sdk/rust; cargo run --quiet --bin conformance
cd sdk/rust; python api-snapshot.py --check
cd sdk/rust; python -m unittest discover -s tests -p "test_*.py" -v
go test ./internal/bridge ./cmd/praxo-bridge
go run ./cmd/praxo-bridge version
python sdk/haskell/run-tests.py
python sdk/haskell/api-snapshot.py --check
cd sdk/c; cmake -S . -B build; cmake --build build; ctest --test-dir build --output-on-failure
cd sdk/csharp; dotnet build Praxo.Core/Praxo.Core.csproj
cd sdk/csharp; dotnet run --project Praxo.Conformance
cd sdk/csharp; dotnet run --project Praxo.Conformance -- --check-api
cd sdk/csharp; dotnet run --project Praxo.Tests
cd sdk/csharp; dotnet run --project samples/VbSample
php sdk/php/conformance/run.php
php sdk/php/conformance/run.php --check-api
php sdk/php/tests/run.php
cd sdk/swift; swift test
cd sdk/swift; swift run praxo-conformance
cd sdk/swift; python3 api-snapshot.py --check
cmake -S sdk/cpp -B sdk/cpp/build; cmake --build sdk/cpp/build; ctest --test-dir sdk/cpp/build --output-on-failure
python sdk/cpp/api-snapshot.py --check
ruby sdk/ruby/conformance/run.rb
ruby sdk/ruby/api-snapshot.rb --check
ruby sdk/ruby/tests/run.rb
lua sdk/lua/conformance/run.lua
python sdk/lua/api-snapshot.py --check
lua sdk/lua/tests/run.lua
cd sdk/dart; dart run conformance/run.dart
cd sdk/dart; python api-snapshot.py --check
cd sdk/dart; dart run tests/run.dart
cd sdk/d; mkdir -p build; dmd -i -Isource -O -release source/conformance.d -of=build/conformance
cd sdk/d; ./build/conformance
cd sdk/d; dmd -i -Isource -O -release source/tests.d -of=build/tests
cd sdk/d; ./build/tests
cd sdk/d; python api-snapshot.py --check
cd sdk/zig; mkdir -p build; zig build-exe src/conformance.zig -O ReleaseSafe -femit-bin=build/conformance
cd sdk/zig; ./build/conformance
cd sdk/zig; zig test src/toolcall.zig
cd sdk/zig; zig test src/jsonschema.zig
cd sdk/zig; zig test src/plugin.zig
cd sdk/zig; zig test src/pii_test.zig
cd sdk/zig; python api-snapshot.py --check
cd sdk/typescript; npm run build
node examples/javascript/sample.mjs
perl sdk/perl/conformance/run.pl
perl sdk/perl/api-snapshot.pl --check
perl sdk/perl/tests/run.pl
julia --project=sdk/julia -e 'using Pkg; Pkg.instantiate()'
julia --project=sdk/julia sdk/julia/conformance/run.jl
julia --project=sdk/julia sdk/julia/api-snapshot.jl --check
julia --project=sdk/julia sdk/julia/test/runtests.jl
Rscript sdk/r/conformance/run.R
Rscript sdk/r/api-snapshot.R --check
Rscript sdk/r/tests/run_tests.R
```

## Compatibility

Unreleased native SDK checks:

```bash
python sdk/fortran/run-tests.py
python sdk/cobol/run-tests.py
```

These checks are partial implementation gates, not complete Core release gates.

- Framework versions start at `0.x`.
- PRAXOVELA product versions are independent.
- Breaking changes require a minor bump before `1.0.0`.
- Publish a compatibility note when a consumer (PRAXOVELA or an external
  product) upgrades.
