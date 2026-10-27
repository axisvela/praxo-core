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
- Keep independent implementations under `language/`, bridge wrappers under
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
cd language/python; python conformance/run.py
cd language/python; python api-snapshot.py --check
cd language/python; python -m unittest discover -s tests -v
cd language/typescript; npm ci
cd language/typescript; npm run build
cd language/typescript; npm run api:check
cd language/typescript; npm run conformance
cd language/typescript; node --test tests/sdk.test.js tests/openaicompat.test.js
cd language/java; mvn -q -DskipTests test-compile
cd language/java; mvn -q -DskipTests package
cd language/java; java -cp target/classes io.axisvela.praxo.conformance.ApiSnapshot --check
cd language/java; java -cp target/classes io.axisvela.praxo.conformance.Run
cd language/java; java --add-modules jdk.httpserver -cp target/classes:target/test-classes io.axisvela.praxo.adapters.OpenAICompatibleSelfTest
cd language/java; java -cp target/classes:target/test-classes io.axisvela.praxo.agent.AgentConcurrencySelfTest
cd language/rust; cargo test
cd language/rust; cargo run --quiet --bin conformance
cd language/rust; python api-snapshot.py --check
cd language/rust; python -m unittest discover -s tests -p "test_*.py" -v
go test ./internal/bridge ./cmd/praxo-bridge
go run ./cmd/praxo-bridge version
python language/haskell/run-tests.py
python language/haskell/api-snapshot.py --check
python language/matlab/run-tests.py
python language/matlab/api-snapshot.py --check
cd language/delphi; fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild praxo.pas
cd language/delphi; python run-tests.py
python language/delphi/api-snapshot.py --check
cd language/ocaml; python run-tests.py
python language/ocaml/api-snapshot.py --check
python language/objc/api-snapshot.py --check
python language/objc/run-tests.py
python language/elixir/api-snapshot.py --check
mkdir -p language/elixir/build/ebin; elixirc -o language/elixir/build/ebin language/elixir/lib/praxo/*.ex
elixir -pa language/elixir/build/ebin language/elixir/tests/run_tests.exs
elixir -pa language/elixir/build/ebin language/elixir/conformance/run.exs
python language/nim/api-snapshot.py --check
nim c --path:language/nim/src --hints:off --out:build/praxo-nim-conformance language/nim/conformance/run.nim
./build/praxo-nim-conformance
nim c --path:language/nim/src --hints:off --out:build/praxo-nim-tests language/nim/tests/run_tests.nim
./build/praxo-nim-tests
python language/v/api-snapshot.py --check
v -o build/praxo-v-conformance language/v/conformance/run.v
./build/praxo-v-conformance
v -o build/praxo-v-tests language/v/tests/run.v
./build/praxo-v-tests
python bindings/lisp/test_bridge.py
python bindings/tcl/test_bridge.py
cd language/c; cmake -S . -B build; cmake --build build; ctest --test-dir build --output-on-failure
cd language/csharp; dotnet build Praxo.Core/Praxo.Core.csproj
cd language/csharp; dotnet run --project Praxo.Conformance
cd language/csharp; dotnet run --project Praxo.Conformance -- --check-api
cd language/csharp; dotnet run --project Praxo.Tests
cd language/csharp; dotnet run --project samples/VbSample
dotnet run --project examples/fsharp/Praxo.FSharp.Sample.fsproj
php language/php/conformance/run.php
php language/php/conformance/run.php --check-api
php language/php/tests/run.php
cd language/swift; swift test
cd language/swift; swift run praxo-conformance
cd language/swift; python3 api-snapshot.py --check
cmake -S language/cpp -B language/cpp/build; cmake --build language/cpp/build; ctest --test-dir language/cpp/build --output-on-failure
python language/cpp/api-snapshot.py --check
ruby language/ruby/conformance/run.rb
ruby language/ruby/api-snapshot.rb --check
ruby language/ruby/tests/run.rb
lua language/lua/conformance/run.lua
python language/lua/api-snapshot.py --check
lua language/lua/tests/run.lua
cd language/dart; dart run conformance/run.dart
cd language/dart; python api-snapshot.py --check
cd language/dart; dart run tests/run.dart
cd language/d; mkdir -p build; dmd -i -Isource -O -release source/conformance.d -of=build/conformance
cd language/d; ./build/conformance
cd language/d; dmd -i -Isource -O -release source/tests.d -of=build/tests
cd language/d; ./build/tests
cd language/d; python api-snapshot.py --check
cd language/zig; mkdir -p build; zig build-exe src/conformance.zig -O ReleaseSafe -femit-bin=build/conformance
cd language/zig; ./build/conformance
cd language/zig; zig test src/toolcall.zig
cd language/zig; zig test src/jsonschema.zig
cd language/zig; zig test src/plugin.zig
cd language/zig; zig test src/pii_test.zig
cd language/zig; python api-snapshot.py --check
cd language/typescript; npm run build
node examples/javascript/sample.mjs
perl language/perl/conformance/run.pl
perl language/perl/api-snapshot.pl --check
perl language/perl/tests/run.pl
julia --project=language/julia -e 'using Pkg; Pkg.instantiate()'
julia --project=language/julia language/julia/conformance/run.jl
julia --project=language/julia language/julia/api-snapshot.jl --check
julia --project=language/julia language/julia/test/runtests.jl
Rscript language/r/conformance/run.R
Rscript language/r/api-snapshot.R --check
Rscript language/r/tests/run_tests.R
```

## Compatibility

Unreleased native SDK checks:

```bash
python language/fortran/run-tests.py
python language/cobol/run-tests.py
```

These checks are partial implementation gates, not complete Core release gates.

- Framework versions start at `0.x`.
- Version tags and `VERSION` files use plain `X.Y.Z`; do not add `-rc`,
  `-beta`, `-alpha`, or other pre-release suffixes.
- PRAXOVELA product versions are independent.
- Breaking changes require a minor bump before `1.0.0`.
- Publish a compatibility note when a consumer (PRAXOVELA or an external
  product) upgrades.
