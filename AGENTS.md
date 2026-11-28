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
- Preserve published URLs through `scripts/discovery/docs_hooks.py` redirects when moving pages.

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
- Keep core and optional adapters in separate directories; Core must not import
  adapter code. See `docs/contributing/adapter-layout.md`.
- Do not add code comments unless asked.

## Git Identity

- Use tagger and author identity `hanhuiwen <hanhuiwen@axisvela.com>` for release
  tags and commits when the user has not specified another identity. Apply it per
  command, for example
  `git -c user.name=hanhuiwen -c user.email=hanhuiwen@axisvela.com tag -a vX.Y.Z -m "PRAXO-CORE X.Y.Z"`;
  do not change the global git configuration.

## Language Implementations

- `spec/` is the normative contract for the Python, TypeScript, Java, and
  independently implemented Core SDKs listed in `spec/languages.md`.
- Go remains the reference implementation; do not widen the `pkg/...` API for an
  SDK.
- Keep independent implementations under `language/`, bridge wrappers under
  `bindings/`, and shared-runtime language samples under `language/go/examples/`.
- Reference applications live at `language/<language>/application/`; tutorials and
  mechanism examples remain under `language/<language>/Tutorial/` and their
  existing paths. PHP may keep multiple variants in subdirectories; other
  languages implement the AI-native application directly.
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
- See `docs/contributing/core-design.md` and `docs/languages/support.md`.
- New languages follow the tier model in `docs/contributing/language-policy.md`; do
  not hand-write a new agent loop without a named consumer.

## Build And Test

### CI Resource Discipline

- A small change must not launch unrelated language, tutorial, or application
  matrices. Use workflow path filters and dependency-aware job filters before
  matrix expansion; maintain `scripts/ci/ci_changes.py` and regenerate routing with
  `python -m scripts.ci.sync_ci_routing` when changing workflow dependencies.
- Documentation, README, registry/discovery metadata, and known documentation
  generators should run their lightweight checks, not all SDK runtime suites.
  Preserve required checks for actual shared-contract and runtime dependencies.
- Test representative routing decisions when adding paths or workflows. Include
  docs-only, single-SDK, application-only, and shared-contract changes.
- Cancel superseded push/PR test runs. Keep publication, deployment, and mirror
  writes serialized rather than cancelling them halfway through a write.
- Prefer focused local checks and rerunning a specific failed job. Do not dispatch
  a full portfolio or rerun hundreds of successful jobs for one failure. Reserve
  broad verification for shared changes, explicit full runs, and release needs.
- Verify the packaged artifact in an isolated consumer, including allow/deny,
  before publication. Source tests and a successful upload do not prove that a
  split archive contains every required runtime file.

### CI Naming And Composition

- Name workflows `<layer>-<subject>.yml`, encoding the responsibility boundary:
  `ci-core.yml`, `ci-security.yml`, `ci-tutorial-php.yml`, `ci-delphi.yml`.
- Name jobs `<subject>/<check>`, for example `php/conformance (8.4)` or
  `php/consumer`, so a failing required check identifies scope without opening the
  workflow.
- Keep `ci.yml` as the small release gate, not the full portfolio. Put scheduled
  or manual full matrices in a separate workflow such as `portfolio.yml`.
- Share setup and repeated logic through composite actions or reusable workflows,
  but keep required checks in direct workflows. Do not nest required checks deeply;
  a required-check name must stay stable and readable as
  `<workflow> / <job>`.
- Split language-specific jobs before adding another matrix row. Do not put
  hundreds of tutorial or SDK jobs in one static workflow when a language-scoped
  workflow would create only the relevant checks.

### Discovery And Publication Content

- Introduce the product as `praxo-core (praxocore)` or
  `PRAXO-CORE (praxo-core, praxocore)` so both searchable names are present.
  Preserve existing package names, imports, URLs, and semantic-version tags.
- Optimize SEO and generative-engine discovery with accurate product identity,
  aliases, supported capabilities, language/runtime, canonical links, useful
  examples, and explicit limitations. Do not claim search ranking or adoption
  gains without measured evidence; avoid irrelevant keyword stuffing.
- Registry publication must include rich, relevant ecosystem-native keywords,
  topics, or tags where supported. Respect registry limits and validate the
  published artifact and rendered page, not only source metadata.
- Maintain relevant topics and descriptions on the canonical repository and all
  discovery mirrors and publication-source split repositories. Include both
  `praxo-core` and `praxocore`; use language/capability topics that match actual
  support. Search topics/tags are separate from immutable release-version tags.
- README and registry introductions must be complete and sensibly ordered:
  product description and fit; getting started and installation; runnable
  examples; scenario tutorials; reference applications and their actual status;
  capabilities and limits; community and support links. Put a useful first run
  before large capability matrices. State planned or unavailable sections rather
  than implying implementation or acceptance.
- Keep root, bilingual, per-language, mirror/split, package-description, and
  coding-agent entries aligned through the existing metadata generators. Run
  their drift and discovery checks; audit registry rendering after publication.

### Local Toolchain Locations

Local toolchains are installed under `D:\dev`. Reuse the existing portable
installations; do not install duplicate toolchains into the user profile or
elsewhere. Add the relevant directory to `PATH` per command when a tool is not
already on `PATH`.

Per-language paths, versions, blockers, and working commands are maintained
internally in
`D:\profile\code\axis-vela\PRAXOVELA-EE\docs\praxo-core\languages\environment-and-configuration.md`.
Swift has an additional Windows setup guide in
`D:\profile\code\axis-vela\PRAXOVELA-EE\docs\praxo-core\languages\swift-windows-toolchain.md`.
Record new toolchain findings and workarounds there.

| Tool / language | Local path |
| --- | --- |
| Go | `D:\dev\Go\bin\go.exe` |
| Python | `C:\Python314\python.exe`; also `D:\dev\Python\Python312` and `Python313` |
| Node.js / npm | `D:\dev\nvm4w\nodejs` |
| Java | `D:\dev\Eclipse Adoptium\jdk-25.0.5.8-hotspot` |
| Maven | `D:\dev\apache-maven-3.9.10\bin\mvn.cmd` |
| Rust | `D:\data\rust\.cargo\bin\cargo.exe` |
| .NET | `C:\Program Files\dotnet\dotnet.exe`; also `D:\dev\dotnet` |
| Elixir | `D:\dev\Elixir\bin\elixir.bat` |
| Erlang / escript / rebar3 | `D:\dev\Erlang OTP\bin`; `D:\dev\rebar3\rebar3.cmd` |
| Ruby | `D:\dev\ruby\bin\ruby.exe` |
| PHP | `D:\dev\php\php.exe` |
| Lua | `D:\dev\lua\bin\lua.exe` |
| Dart | `D:\dev\dart\dart-sdk\bin\dart.exe` |
| Perl | `D:\dev\msys64\usr\bin\perl.exe` |
| Free Pascal | `D:\dev\fpc\bin\i386-Win32\fpc.exe` |
| DMD | `D:\dev\DMD\D\dmd2\windows\bin64\dmd.exe` |
| Clang / MSYS2 | `D:\dev\msys64\mingw64\bin` |
| GCC / G++ / gfortran | `D:\dev\winlibs\mingw64\bin` |
| Zig | `D:\dev\zig\zig-x86_64-windows-0.17.0\zig.exe` |
| Swift | `C:\Users\hanhw1\AppData\Local\Programs\Swift\Toolchains\6.4.2+Asserts\usr\bin` |
| Julia | `D:\dev\julia\bin\julia.exe` |
| GNU Octave | `D:\dev\octave-11.3.0-w64\mingw64\bin\octave-cli.exe` |
| R | `D:\dev\R\bin\Rscript.exe` (also `D:\dev\R45`) |
| Nim | `D:\dev\nim-2.2.12_x64\bin\nim.exe` |
| GHC / runghc | `D:\dev\ghc-9.12.2-x86_64-unknown-mingw32\bin` |
| OCaml | `D:\dev\dkml\usr\bin` |
| V | `D:\dev\v\v\v.exe` |
| GnuCOBOL | `D:\dev\gnucobol\bin\cobc.exe` |
| PowerShell | Windows PowerShell 5.1 or `pwsh` from WindowsApps |

MATLAB is not installed locally. Octave is the local compatibility runtime; do
not claim MATLAB runtime verification from an Octave run.

### Windows Java/Maven Agent Execution

When an agent runs Java or Maven from a persistent shell, redirect stdin from
`NUL`; otherwise the process can block waiting on an inherited console handle.
For example:

```powershell
cmd /d /c "mvn -q -o -DskipTests test-compile < NUL"
cmd /d /c "java -cp target/classes com.axisvela.praxo.conformance.Run < NUL"
```

In Python wrappers, use `stdin=subprocess.DEVNULL` with a timeout and captured
output. This is an execution-environment note, not a product requirement.

```bash
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
cd language/python; python conformance/run.py
cd language/python; python api-snapshot.py --check
cd language/python; python api-signatures.py --check
cd language/python; python -m unittest discover -s tests -v
python -m scripts.discovery.test_sync_language_mirrors
python -m scripts.discovery.sync_language_mirrors --dry-run
python -m scripts.checks.check_adapter_status --check
python -m scripts.checks.test_adapter_status
python -m scripts.checks.check_language_releases
python -m unittest discover -s scripts -t . -p "test_language_releases.py" -v
cd language/typescript; npm ci
cd language/typescript; npm run build
cd language/typescript; npm run api:check
cd language/typescript; npm run conformance
cd language/typescript; node --test tests/sdk.test.js tests/behavior.test.js tests/hitl.test.js tests/openaicompat.test.js tests/api-signatures.test.js
cd language/java; mvn -q -DskipTests test-compile
cd language/java; mvn -q -DskipTests package
cd language/java; java -cp target/classes com.axisvela.praxo.conformance.ApiSnapshot --check
cd language/java; java -cp target/classes com.axisvela.praxo.conformance.Run
cd language/java; java --add-modules jdk.httpserver -cp target/classes:target/test-classes com.axisvela.praxo.adapters.OpenAICompatibleSelfTest
cd language/java; java --add-modules jdk.httpserver -cp target/classes:target/test-classes com.axisvela.praxo.adapters.ProviderAdaptersSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.adapters.OtelSinkSelfTest
cd language/java; java -Xint -cp target/classes:target/test-classes com.axisvela.praxo.plugin.ProcessHostSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.agent.delegation.DelegationSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.retriever.RetrieverSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.agent.AgentConcurrencySelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.agent.AgentAuthorizationSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.agent.AgentLifecycleSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.agent.AgentGuardrailSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.agent.AgentHitlSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.agent.AgentStreamSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.jsonschema.JsonSchemaSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.checkpoint.CheckpointSelfTest
cd language/java; java -cp target/classes:target/test-classes com.axisvela.praxo.middleware.PiiMiddlewareSelfTest
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
python language/octave/run-tests.py --octave octave-cli
python language/octave/api-snapshot.py --check
python language/octave/build_octave_package.py
cd language/delphi; fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild praxo.pas
cd language/delphi; python run-tests.py
cd language/delphi; fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild tests/plugin_process_tests.pas; ./build/plugin_process_tests
python language/delphi/api-snapshot.py --check
cd language/ocaml; python run-tests.py
python language/ocaml/api-snapshot.py --check
python language/objc/api-snapshot.py --check
# build language/c first, then:
python language/objc/run-tests.py
python language/elixir/api-snapshot.py --check
mkdir -p language/elixir/build/ebin; elixirc -o language/elixir/build/ebin language/elixir/lib/praxo/*.ex language/elixir/lib/praxo/adapters/*.ex
elixir -pa language/elixir/build/ebin language/elixir/tests/run_tests.exs
elixir -pa language/elixir/build/ebin language/elixir/conformance/run.exs
python language/erlang/run-tests.py
python language/erlang/api-snapshot.py --check
python language/nim/api-snapshot.py --check
nim c --path:language/nim/src --hints:off --out:build/praxo-nim-conformance language/nim/conformance/run.nim
./build/praxo-nim-conformance
nim c --path:language/nim/src --hints:off --out:build/praxo-nim-tests language/nim/tests/run_tests.nim
nim c --path:language/nim/src --hints:off --passL:language/c/build/libpraxo_core.a --passL:-lm --out:build/praxo-nim-plugin-process language/nim/tests/plugin_process.nim
./build/praxo-nim-plugin-process
./build/praxo-nim-tests
python language/v/api-snapshot.py --check
v -o build/praxo-v-conformance language/v/conformance/run.v
./build/praxo-v-conformance
v -o build/praxo-v-tests language/v/tests/run.v
./build/praxo-v-tests
python bindings/lisp/test_bridge.py
python bindings/tcl/test_bridge.py
python bindings/prolog/test_bridge.py
cd language/c; cmake -S . -B build; cmake --build build; ctest --test-dir build --output-on-failure
cd language/csharp; dotnet build Praxo.Core/Praxo.Core.csproj
cd language/csharp; dotnet run --project Praxo.Conformance
cd language/csharp; dotnet run --project Praxo.Conformance -- --check-api
cd language/csharp; dotnet run --project Praxo.Tests
cd language/csharp; dotnet run --project samples/VbSample
dotnet run --project language/fsharp/examples/Praxo.FSharp.Sample.fsproj
php language/php/conformance/run.php
php language/php/conformance/run.php --check-api
php language/php/tests/run.php
php language/php/tests/plugin_process.php
cd language/swift; swift test
cd language/swift; swift run praxo-conformance
cd language/swift; python3 api-snapshot.py --check
cmake -S language/cpp -B language/cpp/build; cmake --build language/cpp/build; ctest --test-dir language/cpp/build --output-on-failure
python language/cpp/api-snapshot.py --check
g++ -std=c++20 -O2 -I language/cpp/include language/cpp/tests/plugin_process.cpp -L language/c/build -lpraxo_core -o build/praxo-cpp-plugin-process
./build/praxo-cpp-plugin-process
ruby language/ruby/conformance/run.rb
ruby language/ruby/api-snapshot.rb --check
ruby language/ruby/tests/run.rb
lua language/lua/conformance/run.lua
python language/lua/api-snapshot.py --check
lua language/lua/tests/run.lua
cd language/dart; dart run conformance/run.dart
cd language/dart; python api-snapshot.py --check
cd language/dart; dart run test/run.dart
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
node language/javascript/examples/sample.mjs
cd language/java; javac -d build/classes $(find src/main/java -name '*.java')
groovy -cp language/java/build/classes language/groovy/examples/sample.groovy
CLASSPATH=language/java/build/classes clojure language/clojure/examples/sample.clj
cc -std=c11 -DCL_TARGET_OPENCL_VERSION=300 -I language/c/include -I language/c/src language/opencl/examples/sample.c language/c/src/json.c -lOpenCL -lm -o build/opencl-sample
./build/opencl-sample
perl language/perl/conformance/run.pl
perl language/perl/api-snapshot.pl --check
perl language/perl/tests/run.pl
julia --project=language/julia -e 'using Pkg; Pkg.instantiate()'
julia --project=language/julia language/julia/conformance/run.jl
julia --project=language/julia language/julia/api-snapshot.jl --check
julia --project=language/julia language/julia/test/runtests.jl
julia --compile=min --project=language/julia language/julia/tests/plugin_process.jl
Rscript language/r/conformance/run.R
Rscript language/r/api-snapshot.R --check
Rscript language/r/tests/run_tests.R
```

## Compatibility

Additional native SDK checks:

```bash
python language/fortran/run-tests.py
python language/cobol/run-tests.py
```

These commands are implementation gates for the listed SDKs; consult
`spec/languages.md` for release and maturity status.

- The Go reference uses the `v2.x.y` module line. Independent implementations
  version separately; some remain `0.x`.
- Version tags and `VERSION` files use plain `X.Y.Z`; do not add `-rc`,
  `-beta`, `-alpha`, or other pre-release suffixes.
- PRAXOVELA product versions are independent.
- Breaking Go v2 changes require a new major version and module path. For `0.x`
  implementations, breaking changes require a minor bump and migration note.
- Follow `docs/project/compatibility-policy.md` and the normative `spec/` rules;
  optional profiles do not bypass shared wire compatibility review.
- Publish a compatibility note when a consumer (PRAXOVELA or an external
  product) upgrades.
