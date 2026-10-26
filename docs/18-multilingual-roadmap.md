# Multilingual Roadmap

**Status:** execution plan, 2026-10-25. This page sequences the work defined in
[Multilingual SDK design](17-multilingual-sdk.md). Dates and effort are
estimates and may change without a spec change.

## Sequencing Principles

1. **Contract before code.** No SDK implementation starts before the wire
   artifacts and the Go conformance runner exist.
2. **Go proves the vectors.** A vector that the reference implementation does
   not pass is not a contract.
3. **One language at a time.** Python reaches parity before TypeScript starts at
   full capacity; TypeScript before Java. This bounds contract drift.
4. **Core before adapters.** No provider, MCP, OTel, or plugin adapter ships
   before the core contract is green.
5. **No new Go API.** Multilingual work must not widen the frozen `pkg/...`
   surface.

## Phase Overview

| Phase | Outcome | Gate |
| --- | --- | --- |
| 0 | Normative spec, parity inventory, Go vector runner, CI gate | vectors green on Go |
| 1 | Python SDK core at parity, published to PyPI | 11 vectors + parity |
| 2 | TypeScript SDK core at parity, published to npm | 11 vectors + parity |
| 3 | Java SDK core at parity, published to Maven Central | 11 vectors + parity |
| 4 | Optional adapters and plugin hosts by demand | named consumer + evidence |

Internal effort, staffing, and risk tracking live outside this repository.

## Current Status (2026-10-25)

| Item | Status | Evidence |
| --- | --- | --- |
| P0-1 spec skeleton and parity inventory | done | `spec/SPEC_VERSION`, `spec/parity.md` |
| P0-2 event wire artifact | done | `spec/wire/events.json` |
| P0-3 error wire artifact | done | `spec/wire/errors.json` |
| P0-4 plugin wire artifact | done | `spec/wire/plugin.json` |
| P0-5 JSON Schema wire artifact | done | `spec/wire/jsonschema.json` |
| P0-6 behavior vectors | done | eleven groups green: agent loop, toolcall, jsonschema, plugin, memory, event, stream, checkpoint, policy, context, middleware |
| P0-7 Go vector runner | done | `internal/spec` |
| P0-8 `spec-conformance` CI job | done | `.github/workflows/ci.yml` |
| P0-9 parity linter | done | `TestParityInventory` and `TestParitySymbols` in `internal/spec` |

Local check: `GOWORK=off go test -count=1 ./internal/spec/... -v`.

Phase 0's contract extraction exit gate is met.

### Phase 1 Progress (2026-10-25)

| Item | Status | Evidence |
| --- | --- | --- |
| P1-1 core modules | done | `python/praxo/{model,tool,event,policy,memory,checkpoint,agent}.py` |
| P1-2 async loop, cancellation, streaming | done | `Agent`, `AgentOptions.on_delta`, streaming test |
| P1-3 context budget, compaction, offload, `AGENTS.md` | done | `python/praxo/context.py`, context tests |
| P1-4 middleware subset | done | `python/praxo/middleware/`, middleware tests |
| P1-5 OpenAI-compatible adapter | done | `python/praxo/adapters/openaicompat.py`, fake SSE test |
| P1-6 Python conformance runner | done | `python/conformance/run.py`, CI job `python-conformance` |
| P1-7 SDK docs | done | `python/README.md`, `python/API.md`, `python/api/0.2.0.txt` |
| P1-8 PyPI release | ready | wheel/sdist build and clean-venv install pass; publication pending credentials |

Local checks:

```bash
cd python
python conformance/run.py
python -m unittest discover -s tests -v
```

Phase 1's code and documentation gates are met. PyPI publication remains a
release-credential step.

Release state: `spec/v0.2.0` tags the eleven-group contract,
`python/v0.2.0` tags the Python SDK, `typescript/v0.1.0` tags the TypeScript
core, `java/v0.2.1` tags the Java core, `rust/v0.1.0` tags the Rust core implementing
it, `shell/v0.1.0` / `powershell/v0.1.0` tag the bridge wrappers, and
`c/v0.1.0` tags the C conformance core, `csharp/v0.1.0` tags the C# core,
`php/v0.1.0` tags the PHP core, `perl/v0.1.0` tags the Perl core,
`cpp/v0.1.0` tags the C++ core, `ruby/v0.1.0` tags the Ruby core,
`lua/v0.1.0` tags the Lua core, `dart/v0.1.0` tags the Dart core,
`zig/v0.1.0` tags the Zig wire package, and `swift/v0.2.0`, `julia/v0.2.0`, and
`r/v0.2.0` tag their core SDKs. The Swift, Julia, and R `0.1.0` tags remain
available for consumers that pinned the wire subset.

### Phase 2 Progress (2026-10-25)

| Item | Status | Evidence |
| --- | --- | --- |
| P2-1 package and build | done | `typescript/`, `package.json`, `tsconfig.json` |
| P2-2 async loop, streaming, cancellation | done | async loop, `onDelta`, `AbortSignal` |
| P2-3 schema validation | done | dependency-free subset validator; Zod not adopted (D9) |
| P2-4 core loop, middleware, memory, checkpoint, policy, events | done | `typescript/src`, `node --test` |
| P2-5 OpenAI-compatible adapter | done | `typescript/src/adapters/openaicompat.ts`, fake HTTP/SSE tests |
| P2-6 conformance runner and parity | done | `typescript/src/conformance/`, CI job `typescript-conformance` |
| P2-7 npm release | ready | `npm pack` and `npm publish --dry-run` verified; publication pending credentials |

The TypeScript SDK passes all eleven vector groups and its parity check. M2's
code and documentation gates are met; npm publication remains a
release-credential step. VFS and plugin hosts remain optional follow-up work.

### Phase 3 Progress (2026-10-25)

| Item | Status | Evidence |
| --- | --- | --- |
| P3-1 Java module and packages | done | `java/`, `pom.xml`, records |
| P3-2 virtual-thread execution and cancellation | done | virtual-thread executor, `CancellationToken`, concurrency self-test |
| P3-3 JSON codecs | done | dependency-free `util/Json.java`; Jackson not adopted (D10) |
| P3-4 core loop, middleware, memory, checkpoint, policy, events | done | `java/src`, `javac` + `jrun` conformance |
| P3-5 OpenAI-compatible adapter | done | `java/.../adapters`, local HTTP/SSE self-test |
| P3-6 conformance runner | done | `java/.../conformance/Run.java`, CI job `java-conformance` |
| P3-API API snapshot and parity | done | `java/api/0.2.0.txt`, `Parity.check()` |
| P3-7 Maven Central release | planned | Maven build runs in CI; publication pending |

The Java SDK passes all eleven vector groups, its API snapshot/parity check,
and the adapter/concurrency self-tests. Phase 3 is not complete until the
Maven Central release is done.

### Rust and C SDKs (2026-10-25)

| Item | Status | Evidence |
| --- | --- | --- |
| Rust core | done | `rust/`, 11 vector groups, `cargo test` |
| Rust OpenAI adapter | planned | not implemented |
| Rust API snapshot/parity | planned | not implemented |
| C core | done | `c/`, 11 vectors, `ctest`, tagged `c/v0.1.0` |
| C API snapshot/parity | partial | wire-level parity and parity linter; idiomatic agent API pending |

The Rust SDK passes all eleven vector groups and its seven unit tests. C is the
wire-level conformance core; both SDKs use the shared vectors and wire contract.

### C# and VB.NET (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| C# core | done | `csharp/`, 11 vector groups, API snapshot, `dotnet` tests |
| C# OpenAI adapter | done | `OpenAiCompatibleModel`, synchronous and streaming |
| C# API snapshot/parity | done | `csharp/api-snapshot.txt`, `spec/parity/csharp.md` |
| VB.NET sample | done | `csharp/samples/VbSample` |

The C# SDK passes all eleven vector groups, its dependency-free core tests, and
its API snapshot check. The VB.NET sample consumes the same assembly.

### PHP (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| PHP core | done | `php/`, 11 vector groups, API snapshot, tests |
| PHP API snapshot/parity | done | `php/api/0.1.0.txt`, `spec/parity/php.md` |
| PHP provider adapter | planned | not included in `0.1.0` |

The PHP SDK passes all eleven vector groups, its dependency-free tests, and its
API snapshot check. It is a synchronous, standard-library-only package.

### Zig wire package (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| Zig wire | done | `zig/`, toolcall/jsonschema/plugin vectors |
| Zig tests | done | `zig test src/toolcall.zig`, `jsonschema.zig`, `plugin.zig` |
| Zig API snapshot | done | `zig/api/0.1.0.txt` |

The Zig SDK uses only the standard library and passes the three wire vector
groups plus its API snapshot check. It is tagged `zig/v0.1.0`; the core loop
remains a follow-up.

### Kotlin and Scala samples (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| Kotlin sample | done | `kotlin/sample.kt`, `kotlin-sample` CI |
| Scala sample | done | `scala/sample.scala`, `scala-sample` CI |
| Separate JVM cores | not planned | Java remains the source |

Both samples consume the compiled Java SDK. There are no separate Kotlin or
Scala tags.

### Dart core (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| Dart core | done | `dart/`, 11 vector groups, `dart/v0.1.0` |
| Dart tests | done | `dart run tests/run.dart` |
| Dart API snapshot | done | `dart/api/0.1.0.txt` |

The Dart SDK uses only the standard library and passes all eleven vector groups,
its core tests, and its API snapshot check.

### JavaScript sample (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| JavaScript sample | done | `javascript/sample.mjs` |
| JavaScript discovery | done | `javascript/README.md`, `docs/sdks.md` |
| Separate JavaScript core | not planned | TypeScript remains the source |

The sample imports the built TypeScript package from Node and passes in CI.
There is no separate JavaScript tag.

### Lua core (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| Lua core | done | `lua/`, 11 vector groups, `lua/v0.1.0` |
| Lua tests | done | `lua lua/tests/run.lua` |
| Lua API snapshot | done | `lua/api/0.1.0.txt` |

The Lua SDK uses only the standard library and passes all eleven vector groups,
its core tests, and its API snapshot check.

### Ruby core (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| Ruby core | done | `ruby/`, 11 vector groups, `ruby/v0.1.0` |
| Ruby tests | done | `ruby ruby/tests/run.rb` |
| Ruby API snapshot | done | `ruby/api/0.1.0.txt` |

The Ruby SDK uses only the standard library and passes all eleven vector groups,
its core tests, and its API snapshot check.

### C++ core (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| C++ core | done | `cpp/`, 11 vector groups, `cpp/v0.1.0` |
| C++ tests | done | `ctest --test-dir cpp/build` |
| C++ API snapshot | done | `cpp/api/0.1.0.txt` |

The C++20 SDK uses only the standard library and passes all eleven vector
groups, its core tests, and its API snapshot check.

### Perl core (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| Perl core | done | `perl/`, 11 vector groups, `perl/v0.1.0` |
| Perl tests | done | `perl perl/tests/run.pl` |
| Perl API snapshot | done | `perl/api/0.1.0.txt` |

The Perl SDK uses only core modules and passes all eleven vector groups, its 27
tests, and its API snapshot check.

### Swift core (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| Swift core | done | `swift/`, 11 vector groups, `swift/v0.2.0` |
| Swift XCTest | done | `swift test` on macOS |
| Swift API snapshot | done | `swift/api/0.2.0.txt` |

The Swift core passes all eleven vector groups, its XCTest suite, and its API
snapshot check.

### Julia core (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| Julia core | done | `julia/`, 11 vector groups, `julia/v0.2.0` |
| Julia tests | done | `julia --project=julia julia/test/runtests.jl` |
| Julia API snapshot | done | `julia/api/0.2.0.txt` |

The Julia package uses JSON.jl and passes all eleven vector groups and its API
snapshot check.

### R core (2026-10-26)

| Item | Status | Evidence |
| --- | --- | --- |
| R core | done | `r/`, 11 vector groups, `r/v0.2.0` |
| R tests | done | `Rscript r/tests/run_tests.R` |
| R API snapshot | done | `r/api/0.2.0.txt` |

The R package uses a base-R JSON parser and passes all eleven vector groups and
its API snapshot check.

Long-tail language tiers are evaluated in the
[language expansion plan](19-language-expansion.md).

## Phase 0 - Contract Extraction

**Goal:** make "same contract" machine-checkable without changing Go behavior.

### Deliverables

| ID | Deliverable | Evidence |
| --- | --- | --- |
| P0-1 | `spec/SPEC_VERSION`, `spec/README.md`, `spec/parity.md` | reviewed inventory with zero unclassified packages |
| P0-2 | `spec/wire/events.json` | event type, stream kind, payload keys match `docs/event-schema.md` and `pkg/agent/stream` |
| P0-3 | `spec/wire/errors.json` | every exported sentinel mapped to a stable code |
| P0-4 | `spec/wire/plugin.json` | Manifest v1, lifecycle states, process/WASM envelopes |
| P0-5 | `spec/wire/jsonschema.json` | supported and ignored keywords match `pkg/tool/jsonschema` |
| P0-6 | `spec/vectors/*.json` for agent loop, toolcall, jsonschema, memory, checkpoint, policy, stream, plugin | each vector passes the Go runner |
| P0-7 | Go vector runner under `pkg/conformance/vectors` or `spec/runner/go` | `GOWORK=off go test ./...` covers the runner |
| P0-8 | CI job `spec-conformance` | Go job blocks merges on vector failure |
| P0-9 | Parity linter | fails when `spec/parity.md` references a missing SDK symbol or an unlisted Go symbol |

### Exit Gate

- `spec/parity.md` classifies every exported `pkg/...` package.
- Every P0-6 vector group passes on Go.
- CI rejects a wire change that lacks a `SPEC_VERSION` decision.
- No Go source behavior changes except additive test/runner code.

### Notes

- Place the Go runner in a normal Go package so it runs with the existing
  toolchain and does not need a new module.
- Store vectors as JSON with a stable `id`, `group`, `input`, `expect` shape so
  non-Go runners can consume them without a code generator.
- Do not generate idiomatic APIs from the vectors. Vectors validate behavior;
  they do not define source interfaces.

## Phase 1 - Python SDK

**Goal:** a Python developer can build the quickstart agent, stream, use tools,
memory, checkpoints, policy, and events without touching Go.

### Deliverables

| ID | Deliverable | Evidence |
| --- | --- | --- |
| P1-1 | `python/praxo/{model,tool,event,policy,memory,checkpoint,agent}` | imports, typed models, async API |
| P1-2 | Async agent loop with cancellation and streaming | quickstart parity with `examples/quickstart` |
| P1-3 | Context budgets, compaction, offload, `AGENTS.md` loading | behavior vectors |
| P1-4 | Middleware subset: structured output, PII, fallback, call limits, tool selection | one test per middleware |
| P1-5 | `praxo.model.openaicompat` adapter | deterministic SSE test against a fake server |
| P1-6 | Conformance runner over all `spec/vectors` | CI job `python-conformance` |
| P1-7 | `python/README.md`, API reference, migration guide | docs build passes |
| P1-8 | PyPI release `praxo-core` | install-from-wheel test |

### Exit Gate

- All P1 vector groups green.
- Parity linter green for `python/`.
- Public API has docstrings for every exported symbol.
- Cancellation, tool ordering, and fail-closed behavior have dedicated tests.
- No dependency outside the approved permissive list.

## Phase 2 - TypeScript SDK

**Goal:** Node and edge-compatible (where APIs allow) parity for the core agent
loop and tools.

### Deliverables

| ID | Deliverable | Evidence |
| --- | --- | --- |
| P2-1 | `typescript/src` with subpath exports | `exports` map matches the design doc |
| P2-2 | Async-iterable streaming and `AbortSignal` cancellation | stream vectors |
| P2-3 | Zod-backed schema validation for tool inputs | schema vectors |
| P2-4 | Core agent loop, middleware, memory, checkpoint, policy, events | behavior vectors |
| P2-5 | OpenAI-compatible adapter | deterministic fetch/SSE test |
| P2-6 | Conformance runner | CI job `typescript-conformance` |
| P2-7 | npm release `@axisvela/praxo-core` | install-from-tarball test |

### Exit Gate

- All P1 vector groups green.
- Parity linter green for `typescript/`.
- Types are strict; no exported `any` without justification.
- Node 20 and Node 22 matrix passes.
- Browser compatibility is documented, not implied.

## Phase 3 - Java SDK

**Goal:** enterprise parity with Java 21 idioms.

### Deliverables

| ID | Deliverable | Evidence |
| --- | --- | --- |
| P3-1 | `java/praxo-core` module with `io.axisvela.praxo.*` packages | records/sealed interfaces for wire types |
| P3-2 | Virtual-thread execution model and cancellation | concurrency tests |
| P3-3 | Jackson-based wire codecs | round-trip vectors |
| P3-4 | Core agent loop, middleware, memory, checkpoint, policy, events | behavior vectors |
| P3-5 | OpenAI-compatible adapter | fake HTTP server test |
| P3-6 | Conformance runner | CI job `java-conformance` |
| P3-7 | Maven Central release `io.axisvela:praxo-core` | install-from-local-repo test |

### Exit Gate

- All P1 vector groups green.
- Parity linter green for `java/`.
- No reflection-based magic in the agent loop.
- Java 21 and Java 23 matrix passes.
- Javadoc builds without warnings for exported packages.

## Phase 4 - Adapters and Plugin Hosts

Priority order per language:

1. Anthropic and Gemini adapters
2. MCP gateway
3. OpenTelemetry sink
4. VFS plus confined local backend
5. Process plugin host over the shared JSON-Lines contract
6. WASM plugin host

Each item ships only with a named consumer and its own conformance evidence.
WASM hosts are last because runtime bindings and resource limits differ
materially across languages.

## Decision Log

| ID | Decision | Status |
| --- | --- | --- |
| D1 | Go stays the reference implementation at the repository root | accepted |
| D2 | `spec/` is normative; Go validates it | accepted |
| D3 | Wire fields keep existing casing, including `image_url` | accepted |
| D4 | Language order is Python, TypeScript, Java | accepted |
| D5 | Each SDK versions independently and declares `SPEC_VERSION` | accepted |
| D6 | No cross-SDK runtime dependency or FFI | accepted |
| D7 | WASM plugin hosts are last | accepted |
| D8 | Browser support for TypeScript is documented, not promised | accepted |
| D9 | TypeScript uses the dependency-free JSON Schema subset validator; Zod is not adopted | accepted |
| D10 | Java uses the dependency-free JSON utility; Jackson is not adopted | accepted |

## Definition of Done for an SDK

An SDK release is complete only when:

1. Its conformance job is green against the released `SPEC_VERSION`.
2. The parity linter reports no gaps for its declared scope.
3. The quickstart runs from a clean install.
4. Cancellation, streaming, and fail-closed behavior are tested.
5. Security-sensitive behavior has its own tests in that language.
6. Docs list the supported `SPEC_VERSION` and Go reference version.
7. The release is MIT and its dependency licenses are reviewed.

## Release and Tag Strategy

| Artifact | Tag shape | Version line |
| --- | --- | --- |
| Go core | `v2.x.y` | existing |
| Python | `python/v0.x.y` | `0.x` until P1 exit |
| TypeScript | `typescript/v0.x.y` | `0.x` until P2 exit |
| Java | `java/v0.x.y` | `0.x` until P3 exit |
| Spec | `spec/v0.x.y` | `0.x` until first stable contract |

Tags never move. A spec release may be cut without an SDK release, and SDK
releases always name the spec version they target.

## Related Documents

- [Multilingual SDK design](17-multilingual-sdk.md)
- [Architecture](01-architecture.md)
- [Compatibility policy](16-compatibility-policy.md)
- [Release process](09-release.md)
- [Roadmap detail](06-roadmap.md)
