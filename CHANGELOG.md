# Changelog

## [Unreleased]

### Added

- A cross-language compatibility lab runs deterministic conformance, API
  snapshot/signature checks, and parity checks for Python, TypeScript, Java,
  Rust, Fortran, and COBOL, records toolchains and command results, and writes
  JSON and Markdown reports. It is contract evidence only, not provider,
  production, or security verification.
- Added a "When Not to Use PRAXO-CORE" guide covering non-goals, alternative
  starting points, product-owned capabilities, and migration/exit costs.
- Added an evaluation-only workspace runtime profile that composes state, local,
  and sandbox environments while exposing execution tools only from explicit
  capabilities. It does not add a `pkg/...` API or change default behavior.
- Documented language support levels (`maintained`, `community`, `experimental`,
  and `deprecated`) separately from maturity, with matrix assignments pending
  maintainer confirmation.
- Rust source now provides `tool.Gateway`, `GatewayInfo`, `GatewayTool`, and
  `gateway_tools`, plus a `jsonschema.Schema` wrapper with `from_json` and
  `validate`, and a `0.1.2` API snapshot. No source tag is published by this
  change.
- Fortran source now carries the full typed stream-part fields (run/session IDs,
  kind, step, data, timestamp), a `schema`/`schema_from_json` wrapper, and a
  `0.2.1` API snapshot. The validated JSON Schema subset still uses bounded
  ASCII patterns. No source tag is published by this change.
- COBOL source adds an in-memory `praxo-registry` program for tool
  register/get/list/clear under the unreleased API snapshot. It is partial
  parity: no concurrency and no custom spec provider.

## [2.5.2] - 2026-10-30

### Added

- The governed-workspace example validates required controls before model calls,
  binds single-use in-memory approvals to final filesystem arguments, and
  rechecks policy at invocation. Regression fixtures cover control failures,
  post-approval edits, queued revocation, and masked tool errors. This does not
  add a Core profile/API or change ordinary agent defaults.
- The governed-workspace example includes an opt-in context admission path for
  caller-fetched memory and skills. Untrusted material is data-wrapped, approved
  skills are digest-bound, summaries retain lineage, and restore rebuilds
  instructions. It rejects late System injection and unmanaged inputs without
  changing ordinary recall, skill, compaction, or restore behavior.
- The OpenTelemetry adapter has a runnable in-memory example and regression test
  covering event spans and allowlisted data without a collector or model key.
- Added a public verification evidence index covering Core tests, governed
  examples, containment, adapters, A2A/IAM contracts, integration recovery, and
  product effect ledgers, with explicit claim levels and remaining limits.
- Local VFS operations now use `os.Root` after path authorization, preventing a
  symlink swapped after the policy check from redirecting reads, writes, stats,
  listings, deletes, or Grep file access outside the workspace. Absolute
  symlinks are rejected; use relative targets inside the workspace.

### Fixed

- Documentation matrix tests use fixed parsing fixtures and current canonical
  source metadata instead of hard-coded release tags, preventing language
  releases from invalidating documentation gates. Language support pages and
  CI coverage notes now match the latest recorded source tags.

## [2.5.1] - 2026-10-28

### Added

- Go public API snapshot check mode, with nonwriting drift and command-failure
  regressions, enforced on all three Go CI platforms.
- Compiler-derived C public-header snapshots, immutable version baselines, and
  CTest gates for declaration, field, callback, enum, and macro changes.
- A read-only release prerequisite verifies successful CI/docs main-push runs
  for the exact tag SHA before the publication job receives write permissions.
  Main-push documentation builds are no longer path-filtered.

### Changed

- Published Python 0.2.1 as `praxo-core==0.2.1` on PyPI via Trusted Publishing,
  with source tag `python/v0.2.1` and new `api/0.2.1.txt` /
  `api/0.2.1.signatures.txt` baselines. `python/v0.2.0` and its historical
  snapshots remain unchanged. A clean `pip install praxo-core==0.2.1` and
  installed-package smoke passed.
- Published Python 0.2.2 as `praxo-core==0.2.2` on PyPI via Trusted Publishing,
  with source tag `python/v0.2.2`, new `api/0.2.2.txt` /
  `api/0.2.2.signatures.txt` baselines, and historical PII tool-call redaction.
  A clean `pip install praxo-core==0.2.2` and installed smoke passed.
- Released Rust source tag `rust/v0.1.1` with PII tool-call history redaction and
  the Rust conformance inventory gate; exported API is unchanged. Also released
  `elixir/v0.1.1`, `erlang/v0.1.1`, `objc/v0.1.1`, `delphi/v0.2.1`,
  `v/v0.1.1`, `nim/v0.1.1`, `matlab/v0.2.1`, `java/v0.2.2`, and
  `csharp/v0.1.1` with the same PII history fix and their conformance
  inventory gates.
- Published TypeScript `@axisvela/praxo-core@0.1.2` on npm with matching API and
  signature snapshots. The first publication used a short-lived bypass token
  because staged approval was unavailable, so it carries no provenance claim.
  Configure an npm trusted publisher before the next release.
- Public documentation now calls language implementations Core/Core
  implementations instead of SDKs, while preserving third-party provider SDK
  names and historical release notes.
- Compatibility policy now distinguishes rejecting invalid input from tightening
  the documented valid domain, and requires lifecycle/order changes to be
  released with behavioral evidence. Pre-1.0 Core implementation breaking
  changes require a minor version and migration note rather than a silent patch.

### Fixed

- OpenAI-compatible streams now reject EOF without either `[DONE]` or a finish
  reason, and map cached prompt tokens from `prompt_tokens_details`.
- Tool execution no longer starts another tool after cancellation, including
  tools waiting for a parallel execution slot; the worker count is bounded by
  the batch size.
- Scheduler registration rejects nil schedules, empty IDs, and invalid cron
  expressions, and replacing an existing ID removes its previous cron entry.
  `SetEnabled` returns entry-registration errors instead of ignoring them.
- `formatter.WatchFormat.FormatAll` reports per-file formatter failures while
  continuing to format other detected files, instead of silently succeeding.
- PII middleware now redacts historical tool-call arguments before they are sent
  back to a model and handles typed `map[string]string` / `[]string` tool
  results. Nested values are copied without mutating the caller's originals or
  live tool invocation arguments. Python, TypeScript, Java, C#, Rust, Elixir, Erlang,
  Objective-C, V, Nim, and MATLAB now apply the same historical tool-call
  redaction.
- TypeScript source now targets `0.1.3` and derives `SDK_VERSION` consistency
  from a test, fixing the published `0.1.2` artifact's stale `0.1.0` export in
  the next release.
- The C conformance runner validates specVersion, group names, non-empty vector
  groups, unique IDs, and input/expect objects before executing fixtures, with
  negative CTest coverage. Ruby, Perl, Lua, PHP, Rust, C++, Elixir, Erlang, Dart, and D runners
  now reject missing or empty required vector groups; Ruby, Perl, Rust, C++,
  Elixir, Erlang, and Dart have local negative checks. The Objective-C
  conformance harness now also checks specVersion, group, and non-empty vectors.
  The Delphi Python driver preflights the exact group inventory, metadata, and
  non-empty vectors before compiling.
- The OpenAI-compatible adapter maps text/image_url content blocks and
  schema-backed response formats; unsupported blocks and schema-less response
  formats now fail explicitly instead of being silently dropped.
- Go API checks compare declaration sections rather than shell-decoded package
  descriptions, preserve UTF-8 declaration changes, and report declaration diffs.
- Process crash tests use explicit post-start synchronization instead of racing
  the startup health response against immediate child exit.
- Go runs cleanup for middleware entered before startup failure, continues
  remaining AfterRun callbacks after an error, and releases call-limit and tool
  selection state even when a failed run has no Result. The original execution
  error remains primary; startup rejection still emits no run events.
- C conformance invokes the public Core API instead of test-only algorithms,
  including actual checkpoint roundtrips and agent tool history. Tool results
  use `toolId`, and empty event predicates no longer forward all events.
- Split parity validation discovers released Core inventories from the language
  matrix and checks Go declarations, methods, and fields against the API
  snapshot. Fortran and COBOL inventory rows reference the existing Hook and
  Result symbols rather than nonexistent Policy and RunResult names.
- C parity now marks the agent loop and call limits partial: the loop has no
  cancellation path, and call-limit state is not safe to share across
  concurrent runs. Boundary tests cover step, token, usage, and limit edges.
- Conformance runners reject missing, empty, or unexpected vector groups instead
  of succeeding with files that were never executed. Go inventory checks and
  Python/TypeScript diagnostics have negative tests.
- TypeScript adds a source-declaration snapshot covering public signatures,
  fields, optionality, constructors, methods, aliases, enums, and constant
  types, with mutation tests; the historical export-name snapshot is unchanged.
- Release artifacts include a deterministic manifest with tag, commit, spec,
  toolchain, SBOM scope, and attachment hashes. Checksums cover archive, SBOM,
  and manifest; the SBOM remains root-module scoped.
- C adds CMake install rules for the static library and public headers. CI
  compiles and runs a consumer against the installed prefix. pkg-config, CMake
  package config, shared libraries, and ABI guarantees remain out of scope.
- Added a Python Trusted Publishing workflow for `python/v*` tags and manual
  TestPyPI/PyPI dispatch. It verifies version, SPEC_VERSION, tag, builds wheel
  and sdist, consumes both installed artifacts, and publishes via OIDC. Manual
  dispatch defaults to build-only; PyPI publisher configuration and the first
  successful upload remain pending.
- Added TypeScript npm package metadata and a release workflow that verifies the
  repository URL/version/tag, builds and consumes the tarball, stages npm
  packages by default, and allows explicit direct publish after npm trusted
  publisher approval. npm publication remains pending.
- CI installs the Python wheel and sdist and the TypeScript package tarball in
  clean environments, then runs the installed-package smoke tests outside the
  source tree. Registry publication remains pending.
- Python adds a signature snapshot for class constructors, dataclass fields and
  defaults, methods, properties, functions, and constants, with mutation tests.
  The historical export-name snapshot remains unchanged.
- Corrected stale language status text: C now documents its public Core API and
  partial cancellation/concurrency limits, MATLAB/Delphi list all eleven vector
  groups, Tcl records verified Linux CI, COBOL no longer describes its released
  tag as pending, provenance uses current paths and tags, and `spec/`/`AGENTS.md`
  name all independently implemented Core SDKs and current test commands.
- Go validates and repairs final output before completion hooks, checkpoint
  projections, memory writes, and completion notification, for both text and
  structured-tool answers. A completion sink error is returned without a second,
  contradictory failure notification. Completion hooks receive a result copy
  and cannot rewrite validated output or identity; final writes are not transactional.
- Go adopts context compaction output even when replacing an older message with
  a marker leaves the message count unchanged, and reports the compaction hook.
- Recursive local VFS searches recheck each file path before reading it and
  discard partial matches when a path is denied. Filesystem TOCTOU remains open.
- Windows process hosts serialize Job Object close, usage queries, and tree
  termination to avoid handle races during shutdown.

### Added

- Promoted C to a native Core SDK with a public memory/event/checkpoint/policy/
  context/middleware/agent API and source tag `c/v0.2.0`.
- Promoted Delphi/Free Pascal to a native Core SDK with runtime and middleware
  helpers, all eleven vector groups, and source tag `delphi/v0.2.0`.
- Promoted Haskell to a native Core SDK with runtime, middleware, and all eleven
  vector groups; released source tag `haskell/v0.2.0`.
- Promoted MATLAB/Octave to a native Core SDK with all eleven vector groups,
  integrated middleware, and tagged `matlab/v0.2.0`.
- Completed Fortran PII redaction for email, SSN, credit-card, and phone
  patterns, upgraded its Core parity inventory, and tagged it `fortran/v0.2.0`.
- Marked the Elixir, Nim, V, Objective-C, and Erlang Core SDKs complete after
  their integrated middleware surfaces passed their tests and CI jobs.
- Promoted OCaml to a native Core SDK with integrated PII, structured output,
  call limits, and tool selection; released source tag `ocaml/v0.2.0`.
- Added an OpenCL sample in `examples/opencl` that uses the C SDK and an OpenCL
  ICD, with a CPU-capable POCL CI job.
- Added a SWI-Prolog bridge over the maintained bridge CLI, with forwarding,
  UTF-8, error, and exit-code tests, and tagged it `prolog/v0.1.0`.
- Added Groovy and Clojure samples over the Java SDK, with CI jobs and language
  matrix entries.
- Added a native Erlang Core SDK under `language/erlang` with all eleven vector
  groups, native tests, API snapshot/parity, and an OTP 29 CI job; tagged
  `erlang/v0.1.0` with documented partial opt-in surfaces.
- Added an F# sample over the C# / .NET SDK in `examples/fsharp`, registered it
  in the language matrix, and added it to the .NET CI job.
- Added a maturity column to the language support matrix, separate from source
  tags and version numbers; it distinguishes reference, complete, partial,
  sample, planned, and consumer-gated declared scope.
- Tagged source releases `lisp/v0.1.0` and `tcl/v0.1.0`; these are Bridge-stage
  source tags, not package-registry releases.
- Tagged source releases `haskell/v0.1.0`, `matlab/v0.1.0`,
  `delphi/v0.1.0`, and `ocaml/v0.1.0`; these are Wire-stage source tags, not
  package-registry releases, and documented partial surfaces remain.
- Tagged source releases `fortran/v0.1.0`, `elixir/v0.1.0`, `nim/v0.1.0`,
  `v/v0.1.0`, and `objc/v0.1.0`; these are source tags, not package-registry
  releases, and documented partial surfaces remain.
- Registered Groovy, J#, FoxPro, classic Visual Basic, TCL, Q, and Assembly as
  planned or consumer-gated candidates. Clojure and OpenCL were already listed.
- Added the Go-reference US-style phone rule to built-in PII redaction in the
  Elixir, Nim, V, and Objective-C SDKs, with boundary regressions.
- Use collision-resistant run IDs in the Elixir, Nim, and V agent loops, with
  regression tests for rapid successive runs.
- Add a Tcl bridge wrapper over the maintained bridge CLI, with forwarding,
  UTF-8, error, and exit-code tests.
- Opt-in PII redaction, structured-output validation, and per-run model/tool
  call limits in the Elixir, Nim, V, and Objective-C agent loops.
- Opt-in agent tool selection in the Elixir, Nim, V, and Objective-C
  candidates, including end-to-end allow and deny tests.
- Consumer-supplied synchronous model callbacks for the Elixir, Nim, and V
  agent-loop candidates, with multi-step and error regression tests.
- Objective-C event correlation tests for distinct run IDs and session IDs.
- Experimental Haskell, Free Pascal, and MATLAB/Octave agent loops with local
  agent-loop vector tests. These remain Wire-stage candidates pending the
  remaining Framework behavior and verification.
- OCaml experimental agent-loop callback failure tests and local toolchain
  setup instructions. The loop remains unreleased and requires further review.

### Fixed

- Avoid catching `halt/1` inside the Prolog bridge wrapper and tag the fix as
  `prolog/v0.1.1`.
- Preserve unresolved parent path components in the unreleased Elixir, Nim, V,
  Objective-C, and OCaml lexical path checks. These checks still do not provide
  filesystem or symlink containment.
- Preserve nested model state in the unreleased Elixir fallback model and reject
  negative usage in the Haskell experimental agent loop.

### Added

- `language/elixir/`: unreleased native Elixir Core SDK with all eleven vector
  groups, native tests, API snapshot/parity, and a CI job. Verified locally with
  Elixir 1.20.4 on Erlang/OTP 29; release and remote CI are not yet claimed.
- `language/nim/`: unreleased native Nim Core SDK with all eleven vector groups,
  native tests, API snapshot/parity, and a CI job. Verified locally with Nim
  2.2.12 and MinGW; release and remote CI are not yet claimed.
- `language/v/`: unreleased native V Core SDK with all eleven vector groups,
  native tests, API snapshot/parity, and a CI job. Verified locally with V
  0.5.2; release and remote CI are not yet claimed.
- `language/objc/`: unreleased native Objective-C Core SDK with all eleven
  vector groups, native tests, API snapshot/parity, and a CI job. Verified
  locally with clang + GNUstep, including strict JSON duplicate/trailing
  rejection. Apple Foundation, macOS CI, and release are not yet claimed.
- `language/matlab/`: unreleased native MATLAB/Octave Wire-stage candidate targeting
  Framework, with local Octave validation for toolcall, JSON Schema, and plugin
  vectors. MATLAB runtime, remote CI, agent loop, and release are not claimed.
- `language/delphi/`: unreleased native Delphi/Free Pascal Wire-stage candidate
  targeting Framework, with local Free Pascal 3.2.2 validation for toolcall,
  JSON Schema, and plugin vectors. Delphi compiler, remote CI, agent loop, and
  release are not claimed.
- `language/ocaml/`: unreleased native OCaml Wire-stage candidate targeting
  Framework, with local OCaml 4.14.2 bytecode validation for toolcall, JSON
  Schema, and plugin vectors. Native compilation, remote CI, agent loop, and
  release are not claimed.
- `bindings/lisp/`: unreleased SBCL bridge over the maintained runtime, with
  local UTF-8, forwarding, error, and exit-code tests. It does not implement a
  Lisp agent loop; remote CI and consumer details remain pending.
- Rust compiler-derived public API snapshots and parity symbol checks, with
  regression tests for rustdoc extraction and stale-page exclusion. No Rust
  runtime APIs or dependencies changed.
- `language/haskell/`: unreleased native Wire candidate for strict JSON, tool-call
  parsing, bounded JSON Schema validation, and plugin manifest checks. Local
  tests pass 24 shared vectors across three declared groups, native regressions,
  and source API/parity checks. No agent loop or Hackage release is claimed.
- `language/swift/Sources/PraxoCore`: Swift core loop, middleware, context, memory,
  checkpoint, policy, event, and conformance dispatch for all eleven vector
  groups.
- Julia and R core loops with conformance wiring for all eleven vector groups.
- Swift, Julia, and R `0.2.0` core SDKs with API snapshots, tagged
  `swift/v0.2.0`, `julia/v0.2.0`, and `r/v0.2.0`.
- `perl/`: Perl core SDK with all eleven vector groups, 27 tests, an API
  snapshot, and the `perl-conformance` CI job. Tagged `perl/v0.1.0`.
- `cpp/`: C++20 core SDK with all eleven vector groups, core tests, an API
  snapshot, and the `cpp-conformance` CI job. Tagged `cpp/v0.1.0`.
- `ruby/`: Ruby core SDK with all eleven vector groups, core tests, an API
  snapshot, and the `ruby-conformance` CI job. Tagged `ruby/v0.1.0`.
- `lua/`: Lua 5.4 core SDK with all eleven vector groups, core tests, an API
  snapshot, and the `lua-conformance` CI job. Tagged `lua/v0.1.0`.
- `javascript/`: Node sample that consumes the TypeScript package, with a CI
  smoke job. No separate JavaScript core or tag.
- `dart/`: Dart core SDK with all eleven vector groups, core tests, an API
  snapshot, and the `dart-conformance` CI job. Tagged `dart/v0.1.0`.
- `kotlin/` and `scala/`: JVM samples that consume the Java SDK, with
  `kotlin-sample` and `scala-sample` CI jobs. No separate tags.
- Language expansion now also tracks D, Objective-C, VBScript, and Zig.
- `zig/`: Zig 0.17 core SDK with all eleven vector groups, tests, an API
  snapshot, and the `zig-conformance` CI job. Core tagged `zig/v0.2.0`;
  `zig/v0.1.0` remains the wire tag.
- `d/`: D core SDK with all eleven vector groups, tests, an API snapshot, and
  the `d-conformance` CI job. Tagged `d/v0.1.0`.
- Wave 2 language plan for JavaScript, C++, Dart, Ruby, Kotlin, Scala, MATLAB,
  Perl, Delphi, OCaml/Caml, Lua, Scratch, COBOL, Prolog, and ABAP. C++, Ruby,
  Perl, Lua, and COBOL target core tier.
- `docs/languages/index.md` and `docs/getting-started/index.md` for SDK discovery and docs
  navigation.
- `internal/spec/privacy_test.go`: opt-in git-history and working-tree checks
  for non-public email domains and internal hostnames.
- Multilingual SDK design (`docs/contributing/core-design.md`) and roadmap
  (`docs/languages/support.md`) for Python, TypeScript, and Java SDKs.
- `spec/` scaffold: `SPEC_VERSION`, event/error/schema/plugin wire artifacts,
  `parity.md`, and the conformance-vector format.
- Conformance vectors for the agent loop, toolcall, JSON Schema, plugin,
  memory, event, stream, checkpoint, and policy groups.
- `internal/spec`: the Go vector runner, spec-version checks, wire-reference
  checks, and the parity linter.
- `spec-conformance` CI job.
- `language/python/praxo`: Python SDK core for model, tool, event, policy, memory,
  checkpoint, agent loop, streaming, and JSON Schema validation.
- `language/python/praxo/adapters/openaicompat`: OpenAI-compatible adapter with
  non-streaming and SSE streaming paths.
- `language/python/conformance/run.py` and the `python-conformance` CI job. The Python
  SDK passes all eleven conformance vector groups.
- Python context management: `ContextBudget`, deterministic compaction,
  `ModelSummarizer`, offload hooks, and bounded `AGENTS.md` loading.
- Python middleware: call limits, fallback model, PII redaction, structured
  output, and tool selection, integrated into the agent loop.
- `spec/vectors/context.json`: token estimation, deterministic compaction,
  truncation, and fail-closed budget vectors for Go and Python.
- `spec/vectors/middleware.json`: PII, structured output, call limits, tool
  selection, and fallback vectors for Go and Python.
- `language/python/API.md`, `language/python/api-snapshot.py`, and `language/python/api/0.2.0.txt`.
- Python wheel and sdist build verified in a clean virtual environment.
- `typescript/`: TypeScript SDK core for model, tool, event, policy, memory,
  checkpoint, context, middleware, streaming, and the agent loop.
- `language/typescript/src/conformance/run.ts` and the `typescript-conformance` CI job.
  The TypeScript SDK passes all eleven conformance vector groups.
- TypeScript package build, `node:test` smoke coverage, and npm lockfile.
- TypeScript `AbortSignal` cancellation and OpenAI-compatible adapter with
  non-streaming and SSE paths.
- `language/typescript/api-snapshot.js`, `language/typescript/api/0.1.0.txt`, and the TypeScript
  parity check.
- TypeScript `npm pack` and `npm publish --dry-run` verification. Publication
  remains a release-credential step.
- Decision D9: TypeScript keeps the dependency-free JSON Schema subset
  validator instead of adopting Zod.
- `java/`: Java 21 SDK core for model, tool, event, policy, memory, checkpoint,
  context, middleware, streaming, and the agent loop.
- `language/java/.../conformance/Run.java` and the `java-conformance` CI job. The Java
  SDK passes all eleven conformance vector groups.
- Decision D10: Java keeps the dependency-free JSON utility instead of adopting
  Jackson.
- Java virtual-thread model/tool execution and `CancellationToken` cancellation.
- Java OpenAI-compatible adapter with non-streaming and SSE paths, plus local
  adapter and concurrency self-tests.
- Java API snapshot (`language/java/api/0.2.0.txt`), `ApiSnapshot --check`, and the
  Java parity checker.
- `rust/`: Rust SDK core for model, tool, event, policy, memory, checkpoint,
  context, middleware, streaming types, and the agent loop.
- `language/rust/src/bin/conformance.rs`, the `rust-conformance` CI job, and seven
  Rust unit tests. The Rust SDK passes all eleven conformance vector groups.
- Rust SDK `0.1.0` source tag `rust/v0.1.0`.
- `docs/contributing/language-policy.md`: tiered plan for C#, Visual Basic,
  PowerShell, Shell, PHP, Swift, R, Julia, Haskell, Fortran, and Lisp.
- `spec/languages.md`: canonical language support matrix.
- `spec/bridge.md` and `cmd/praxo-bridge`: process bridge for toolcall,
  JSON Schema, plugin validation, version, tool listing, run, and event
  streaming, with unit tests.
- Shell and PowerShell bridge wrappers with a CI smoke job, tagged
  `shell/v0.1.0` and `powershell/v0.1.0`.
- `c/`: C11 conformance core with JSON, toolcall, JSON Schema, plugin,
  memory, event, checkpoint, policy, context, middleware, and agent vectors.
  Tagged `c/v0.1.0`; the public API is wire-level.
- `csharp/`: .NET 8 C# core with all eleven vector groups, an API snapshot,
  dependency-free tests, OpenAI-compatible streaming, and a VB.NET sample.
  Tagged `csharp/v0.1.0`.
- `php/`: PHP 8 core with all eleven vector groups, an API snapshot, and
  dependency-free tests. Tagged `php/v0.1.0`.
- `swift/`: Swift wire package for toolcall, JSON Schema, and plugin
  manifests, with XCTest coverage and a macOS CI job. Tagged `swift/v0.1.0`.
- `julia/`: Julia wire package for toolcall, JSON Schema, and plugin
  manifests, with JSON.jl, tests, and a `julia-conformance` CI job. Tagged
  `julia/v0.1.0`.
- `r/`: R wire package with a base-R JSON parser, tests, and an
  `r-conformance` CI job. Tagged `r/v0.1.0`.
- Split per-language parity inventories under `spec/parity/` with a structural
  linter.

### Changed

- Planned language entries no longer display hypothetical release tags.
- Documentation navigation is grouped by Quickstart, Adoption, Comparison,
  Adapters, Event Schema, Security, Compatibility, Plugin Authoring, Language
  SDKs, Releases, and Reference.
- Internal effort, staffing, release-runbook, provenance, and containment
  details moved to the private EE documentation tree.
- Public docs no longer contain internal hostnames, codenames, signing key IDs,
  or non-public contact details.
- The contract advances to `SPEC_VERSION` `0.2.0` with the context and
  middleware vector groups.
- The Python SDK advances to `0.2.0` and declares `SPEC_VERSION` `0.2.0`.
- The Java SDK advances to `0.2.0` with the OpenAI adapter, virtual-thread
  execution, and cancellation, then to `0.2.1` with the API snapshot and
  parity release tooling.

### Fixed

- Privacy tests now scan the repository root and new untracked files instead
  of only the test package directory; example endpoints use public placeholders.
- D compiler CI downloads use a pinned official GitHub release artifact with
  SHA256 verification, avoiding the failing upstream download/GPG-key service.

### Compatibility

- No Go API changes. `spec/` and the new docs are additive.

## [2.5.0] - 2026-10-24

### Added

- `pkg/conformance`: reusable contract checks for VFS backends, memory stores,
  sandbox runners, event sinks, policy hooks, gateways, models, streaming
  models, tools, and retrievers.
- `conformance.Run` executes named checks and reports all failures in one pass.

### Fixed

- `pkg/vfs/localfs` rejects NUL bytes, Windows drive-relative paths, reserved
  device names, alternate data streams, and trailing dots or spaces.

### Changed

- Added event and OpenTelemetry schema compatibility notes.
- Added the plugin trust and SBOM product handoff checklist.
- Added the workspace/session evaluation and offline E2B, Daytona, OpenSandbox,
  and CubeSandbox adapter modules. The adapters remain optional, untagged
  evaluation modules.

### Compatibility

- `pkg/conformance` is a new additive package.
- Existing exported `pkg/...` declarations are unchanged from 2.4.0.

## [2.4.0] - 2026-10-24

### Added

- `examples/quickstart` streams text deltas through `agent.Options.OnDelta` and
  includes a deterministic SSE regression test. Events are written to stderr.
- `examples/ecosystem/mcp` is a separate module that demonstrates MCP resources
  and prompts with an in-memory server.
- `BenchmarkAgentMemoryRecall` measures recall from a deterministic in-memory
  store.

### Changed

- Quickstart, benchmark, ecosystem, and release docs describe the streaming
  path, memory recall scenario, and optional `adapters/<name>/vX.Y.Z` tags.
- CI runs the new MCP example module in the examples and module-security
  matrices.

### Compatibility

- No exported `pkg/...` API changes; `api/2.4.0.txt` is identical to
  `api/2.3.6.txt`.
- Optional adapter versions are unchanged.

## [2.3.6] - 2026-10-24

### Fixed

- `pkg/formatter`: an empty formatter command returns an error instead of
  panicking, `List`/`AllAvailable`/`Detect` no longer expose shared extension
  slices, and `FormatAll` returns filesystem walk errors.

## [2.3.5] - 2026-10-24

### Fixed

- `pkg/scheduler`: disabling a schedule now rejects callbacks that have not
  started and waits for an in-flight dispatch to finish before returning.

## [2.3.4] - 2026-10-24

### Fixed

- `pkg/tool/jsonschema`: reject `nil` for typed schemas, reject fractional
  values for `integer`, apply `enum` to numeric and boolean values, treat
  `pattern` as a regular expression, and count Unicode code points for length.
- The tool schema boundary is documented explicitly: unsupported `$ref`,
  composition, `additionalProperties`, and `format` keywords are ignored, and a
  `minimum` or `maximum` of zero is treated as unset.

### Changed

- HTTP client tests now cover idempotent retries, non-idempotent server errors,
  cancellation during backoff, disabled body bounds, request-header precedence,
  malformed JSON, and base-URL path joins.

## [2.3.3] - 2026-10-24

### Fixed

- Recheck final tool names and reauthorize changed JSON arguments after
  preparation callbacks, before executing the batch. Original denials still
  stop preparation; unchanged calls keep one tool-policy request.
- Release checks stop on every failed Go command, including race and fuzz
  checks, instead of letting later successes mask failures.

### Changed

- Linux race and vulnerability checks now cover all seven independent adapter
  modules, ecosystem SDK recipes, and the published-module consumer.
- Security support, MCP schema-preserving registration, optional supervisor
  boundaries, and Go 1.26.10 guidance are aligned with the delivered modules.
- No exported `pkg/...` API changes; optional adapter tags are unchanged.

## [2.3.2] - 2026-10-23

### Changed

- Provider and security recipes now document schema-preserving MCP registration,
  static egress routes, policy credential handling, event-data hygiene, and
  sandbox and workspace boundaries.

### Fixed

- `adapters/gemini` streaming now consumes only the first candidate, matching
  the non-streaming response behavior.

## [2.3.1] - 2026-10-23

### Added

- `adapters/a2a`: in-process gRPC client/server round-trip test.

### Changed

- `examples/multiagent` uses `SubagentManager.Wait` instead of polling.
- The sandbox recipe accepts both `[]string` and `[]any` command arguments
  without panicking or referencing an out-of-scope variable.
- The docs workflow builds on pull requests with `mkdocs build --strict`.

### Fixed

- `SubagentManager.Wait` returns the terminal snapshot to every concurrent
  waiter, including when the task is pruned concurrently.

## [2.3.0] - 2026-10-23

### Added

- `delegation.SubagentManager.Wait` blocks until a task reaches a terminal
  state and returns its final snapshot.
- `delegation.SubagentManager.Prune` removes terminal tasks older than a
  caller-supplied duration.
- `adapters/multiagent` waits on completion events instead of polling;
  `Supervisor.PollInterval` is retained but ignored. `MaxConcurrency` bounds
  parallel workers in `Run`.
- `adapters/openaicompat`: opt-in `IncludeUsage` requests streamed token usage
  and maps it into `model.Usage`.

### Changed

- `memory.MemoryStore` generates collision-resistant IDs with a per-store
  counter and precomputes search text on `Put`; the zero value is usable.

### Fixed

- `flow.Parallel` now invokes runnables concurrently while preserving output
  order; it returns the first error by index after all calls finish.
- `delegation.SubagentManager` no longer overwrites completed/failed tasks on
  `Cancel`; `Update` is rejected unless the task is running.
- `adapters/mcp`: resource and prompt listings reject repeated pagination
  cursors; multi-page listing is covered by tests.
- `adapters/a2a`: added an in-process HTTP JSON-RPC client/server round-trip
  test.

## [2.2.0] - 2026-10-23

### Added

- `adapters/otel`: optional OpenTelemetry event sink mapping lifecycle events to
  spans.
- `adapters/anthropic`: native Anthropic Messages adapter with tool calls,
  usage, and SSE streaming.
- `adapters/gemini`: native Gemini generateContent adapter with function calls
  and SSE streaming.
- `adapters/harmovela`: HTTP event sink for Harmovela without importing the
  heavier Harmovela Go module.
- `adapters/a2a`: A2A server executor adapter for exposing a PRAXO-CORE agent to
  agent-to-agent clients.
- `adapters/multiagent`: optional parallel supervisor and sequential delegation
  over `pkg/agent/delegation`.
- `adapters/mcp`: resource and prompt listing/reading helpers in addition to the
  tool gateway.
- `examples/multiagent`: asynchronous subagent delegation, aggregation, and
  cancellation example, plus bilingual multi-agent guidance.
- `examples/plugin`: minimal process plugin host with JSON-Lines and end-to-end
  tests, plus a WASM host smoke example.
- `examples/checkpoint`: in-memory checkpoint store and session resume flow.
- `examples/sandbox`: policy-gated command execution with a strict allowlist.
- `examples/ecosystem-sdk`: AEGIVELA policy, LIMENORA tool-gateway, and RHEOVELA
  workflow recipes.
- Adapter index, bilingual multi-agent guidance, and deeper ecosystem docs.

### Security

- `adapters/otel`: exclude `Event.Data` by default; export only fields explicitly
  selected by `AllowedDataKeys`. Published v0.1.0 exports all event data.

### Fixed

- `adapters/mcp`: add `NewTools` to preserve input schemas in model-visible tool
  specifications; tool discovery follows pagination and rejects repeated cursors.

### Changed

- No `pkg/...` API changes; the `1.0.0` API freeze remains in effect.
- CI and release workflows pin Go `1.26.10` for the `crypto/x509` fix in
  GO-2026-6809.

### Modules

Optional adapter modules are versioned independently:
`adapters/mcp/v0.2.0`, `adapters/otel/v0.2.0`, `adapters/anthropic/v0.1.0`,
`adapters/gemini/v0.1.0`, `adapters/harmovela/v0.1.0`, `adapters/a2a/v0.1.0`,
and `adapters/multiagent/v0.1.0`.

## [2.1.0] - 2026-10-22

### Added

- `adapters/openaicompat`: standard-library OpenAI-compatible model adapter with
  tool calls, tool choice, usage accounting, and SSE streaming.
- `adapters/mcp`: optional module mapping MCP tools to `tool.Gateway`.
- `examples/quickstart`: Ollama and OpenAI-compatible quickstart.
- `examples/reference`: workspace agent with confined VFS tools, policy, memory,
  events, and context budget.
- `examples/ecosystem`: callback-based adapter skeletons for AxisVela components.
- `examples/ecosystem-sdk`: real NOETIVELA, Mnemovela, and GNOSIVELA SDK recipes.
- Agent-loop benchmarks and a benchmark CI job.
- Bilingual docs site, adoption guide, recipes, Chinese documentation, and
  deeper ecosystem comparison.

### Changed

- No `pkg/...` API changes. The `2.0.0` exported surface remains frozen.

### Community

- Added `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue/PR templates, and GitHub
  Discussions.

## [2.0.0] - 2026-10-18

### Changed

- Module path is now `github.com/axisvela/praxo-core/v2`; all imports use
  `/v2/pkg/...`.
- No functional API changes: capability packages, root aliases, JSON tags, and
  wire contracts are unchanged.

### Migration

- See `docs/project/migration-v2.md`.

All notable changes to PRAXO-CORE are documented here.

## [1.7.0] - 2026-10-18

### Added

- `agent.ContextEditingMiddleware`: clear old tool results while preserving
  message pairing.
- `agent.TodoList`, `agent.TodoTool`, and `agent.TodoMiddleware`:
  `write_todos` planning state and prompt injection.

## [1.6.0] - 2026-10-18

### Changed

- Split `pkg/agent` into capability packages: `types`, `context`,
  `delegation`, `evaluation`, `hitl`, `stream`, and `middleware`. The root
  package keeps `Agent`, `Options`, `New`, `Run`, and compatibility aliases.

### Added

- `checkpoint.Allowlist`: explicit type registration for persisted payloads
  with `Envelope` and `ErrTypeNotAllowed`.
- `agent.StreamKind`, `agent.StreamPart`, and `Options.OnStream`: typed
  projections for values, updates, messages, tasks, debug, and checkpoints.
  Stream errors abort the run.
- Session-level resume is characterized by `Session.Messages`; durable
  checkpoint storage remains product-owned.

## [1.5.0] - 2026-10-18

### Added

- `agent.InterruptAction`, `agent.InterruptDecision`, and
  `Options.OnInterruptDecision`: approve/edit/reject/respond decisions for
  tool-call interrupts. `OnInterrupt` remains supported for boolean approvals.
- `ErrInterruptDecisionInvalid` for unsupported or incomplete decisions.

## [1.4.0] - 2026-10-18

### Added

- `agent.StructuredOutput`: provider/tool/auto JSON-schema binding with
  validation, optional repair, and a virtual structured-output tool.
- `agent.ToolSelector`, `agent.ToolSelectionMiddleware`, and
  `agent.ModelToolSelector`: per-run tool narrowing with a model-backed
  selector.
- `agent.PIIRule`, `agent.PIIRedactor`, `agent.PIIMiddleware`, and
  `DefaultPIIRules`: model-request and tool-result redaction.
- `agent.FallbackModel`: model middleware that retries a failed primary call on
  a fallback model.
- `agent.CallLimitMiddleware` with `ErrModelCallLimit`/`ErrToolCallLimit`:
  per-run model/tool call budgets.
- `tool.Retry` and `tool.RetryPolicy`: retry middleware for tool invocations.
- `Options` wiring for structured output, fallback model, tool selector, PII
  redactor, call limits, and tool retry.

## [1.3.0] - 2026-10-18

### Added

- `model.ProviderProfile` and `model.ProfileRegistry`: provider/model
  capability profiles with longest-prefix resolution.
- `agent.Rubric`, `agent.Evaluator`, and `agent.RubricMiddleware`: final-output
  rubric evaluation with fail-closed scoring.
- `sandbox.Interpreter` and `sandbox.InterpreterFunc`: optional in-process
  script interpreter seam for products that supply a runtime.

## [1.2.0] - 2026-10-18

### Added

- `pkg/vfs`: virtual filesystem backend contract, entries, matches, and
  optional execution capability.
- `pkg/vfs/localfs`: confined local-directory backend with symlink, traversal,
  and sibling-prefix rejection.
- `pkg/vfs/vfstools`: `fs.list`, `fs.read`, `fs.write`, `fs.edit`, `fs.delete`,
  `fs.glob`, `fs.grep`, and optional `fs.execute` tool adapters.
- `agent.SubagentManager`: asynchronous subagent lifecycle with launch, check,
  update, cancel, and list, plus isolated and fork modes.

## [1.1.0] - 2026-10-18

### Added

- `agent.ContextCompactor` and `agent.ModelSummarizer`: model-based
  summarization of older context before the deterministic budget pass.
- `agent.Offloader` / `agent.OffloadFunc`: replace oversized tool results with
  caller-owned offload placeholders; `OnOffload` reports the replacement.
- `agent.LoadAgentsMD` and `Options.MemoryFiles`: always-loaded `AGENTS.md`
  context, bounded by `MaxAgentsMDBytes`.
- `model.CacheHint` and `Options.PromptCache`: provider-neutral prompt-cache
  hook for stable prefixes.

## [1.0.0] - 2026-10-18

### Changed

- Exported API frozen; see `docs/project/api-stability.md`.
- Removed the deprecated `pkg/output`, `pkg/format`, and `pkg/tool/schema`
  aliases. Use `pkg/toolcall`, `pkg/formatter`, and `pkg/tool/jsonschema`.
- API snapshot `api/1.0.0.txt`; the diff from `0.16.0` is alias removal only.

### Fixed

- Scheduler callback now updates schedule state under the engine lock and
  dispatches a snapshot, removing the cron data race.
- Process limit tests skip platforms where RLIMIT_AS/RLIMIT_NPROC are not
  reliable against the Go test-binary fixture; Windows Job Object coverage
  remains.

## [0.16.0] - 2026-10-18

### Added

- Fuzz seeds for the manifest, tool-call, JSON Schema, and path parsers.
- CI matrix (Linux/Windows/macOS), race, fuzz, staticcheck, and govulncheck
  jobs.
- `examples/integrator`: a self-contained external-integrator wiring example.
- API snapshot/diff scripts, release-check gate, SBOM/checksums scripts, and a
  tag-triggered release workflow.
- `docs/guides/plugins.md`: Manifest v1, process/WASM protocol, TCK usage.

### Changed

- Canonical package paths are now `pkg/toolcall` (was `pkg/output`),
  `pkg/formatter` (was `pkg/format`), and `pkg/tool/jsonschema` (was
  `pkg/tool/schema`). The old paths remain as deprecated aliases through the
  `0.16` line and are removed in `1.0.0`; migration is tracked in
  `docs/project/api-stability.md`.
- `toolcall.ToolCall` documents `Operation`, `Resource`, `Risk`, `Reason`, and
  `IdempotencyKey` as optional product governance metadata; the parser does not
  interpret or validate them.
- `pkg/httpclient` bounds response bodies by default (`DefaultMaxBodyBytes`,
  32 MiB), with `Config.MaxBodyBytes` and `ErrBodyTooLarge` for callers.

## [0.15.0] - 2026-10-18

### Added

- `pkg/plugin/host/process` and `pkg/plugin/host/wasm`: process and WASM
  plugin hosts with platform resource supervisors, wire envelopes, and
  conformance tests. PRAXOVELA re-exports them as thin aliases.
- `pkg/plugin/bridge`: generic `plugin.Host` adapters for `tool.Tool`,
  `model.Model`, `policy.Hook`, `memory.Store`, and `sandbox.Sandbox`, with an
  injectable codec and configurable contract methods.
- Process host `Config.TokenEnvVar` for products that need a non-default
  channel-token environment variable; the v1 default remains
  `PRAXOVELA_PLUGIN_TOKEN`.
- `pkg/plugin/tck`: contract-level conformance kit for lifecycle, guarded
  registry, and host framing, timeout, cancellation, capability denial, and
  the not-active gate. Trust, materialization, evidence, and rolling-update
  conformance stay in PRAXOVELA.
- `pkg/plugin` Manifest v1: strict parsing and validation for schema version,
  reverse-DNS identity, semver, contract kind, entrypoint, isolation, protocol,
  capabilities, permissions, limits, health, signature, and SBOM, with signed
  and explicit unsigned trust profiles.
- `pkg/policy`: deny-by-default path containment checker (`PathChecker`) with
  read/write/readwrite grants, symlink resolution, traversal and sibling-prefix
  rejection, and Windows case-insensitive comparison.
- `pkg/agent`: `ContextBudget` prompt compaction with keep-recent turns,
  tool-call/result pairing, a deterministic token estimate, an
  `OnCompaction` hook, and fail-closed `ErrContextBudget` when the system
  prompt alone cannot fit.

### Changed

- `wazero` and `golang.org/x/sys` are direct framework dependencies for the
  WASM host and platform supervisors.

## [0.14.0] - 2026-10-18

### Added

- `pkg/plugin`: contract kinds, host boundary, lifecycle FSM, guarded adapter
  registry, per-plugin scope, resource limits, and telemetry events.
  PRAXOVELA aliases it; materialization, update, evidence, and binding stay
  product-side.

## [0.13.0] - 2026-10-18

### Added

- `pkg/httpclient` shared retry-capable HTTP transport with auth, tracing,
  idempotency-aware retries, and response decoding. PRAXOVELA adapters alias it.

## [0.12.0] - 2026-10-18

### Added

- `agent.Middleware` with before/after run, model, and tool hooks. Middleware
  may rewrite requests or skip execution with a canned result. Named entries
  replace earlier entries in place.

## [0.11.0] - 2026-10-18

### Added

- `Profile` bundles reusable defaults; explicit `Options` values win.
- `ModelMiddleware` wraps model calls in order.

## [0.10.0] - 2026-10-18

### Added

- `SkillProvider` and `Agent.Skills` for on-demand knowledge injection.
- `model.ResponseFormat` and `Agent.ResponseFormat` for structured output.
- `Agent.InterruptOn`/`OnInterrupt` for human approval before tool calls.
- `RunContext`, `RunWithContext`, `WithRunContext`, and `RunContextFrom` for
  per-run values.
- `agent.SessionStore` as the portable session persistence contract.

## [0.9.0] - 2026-10-18

### Added

- `New(Options)` constructor bundling model, prompt, tools, memory, policy,
  budgets, retry, hooks, and streaming.
- `Agent.SystemPrompt` is prepended as a system message.

## [0.8.0] - 2026-10-18

### Added

- `Agent.ToolChoice` and `Agent.AllowedTools` for tool-choice control and
  allowlisting (advertised and enforced).
- `Agent.MaxTokens` token budget with `ErrMaxTokens`.
- `Agent.Recall`/`RecallLimit` to inject matching memory records, plus
  `Hooks.OnMemoryRead` and `Hooks.OnMemoryWrite`.

## [0.7.0] - 2026-10-18

### Added

- `Agent.MaxParallelTools` runs tool calls from one model response
  concurrently while preserving message order.
- Tool panics are converted into errors instead of crashing the process.

## [0.6.0] - 2026-10-18

### Added

- `model.StreamingModel` for callback-based text streaming; set
  `Agent.OnDelta` to receive fragments.
- `Agent.Retry` (`RetryPolicy`) with attempt budget, backoff, and an optional
  retry predicate.
- `Agent.Hooks` lifecycle callbacks for run, step, model, tool, completion, and
  failure events.

### Fixed

- `Agent.Run` no longer mutates `MaxSteps` when it applies the default, making
  a shared agent safe for concurrent runs.

## [0.5.0] - 2026-10-18

### Added

- Extracted durable checkpoint snapshot types and the `Store` contract into
  `pkg/checkpoint`; PRAXOVELA keeps only the effect-ledger cursor builder.

## [0.4.0] - 2026-10-18

### Added

- Extracted the agent lifecycle `Status` state machine and tenant default into
  `pkg/agent`; PRAXOVELA now aliases the framework status contract.

## [0.3.0] - 2026-10-18

### Added

- Extracted PRAXOVELA's code formatter registry into `pkg/format`; PRAXOVELA
  now aliases the framework package.
- Added tool specs, middleware, and ordered wrapping.
- Added multi-sink and filter event sinks.
- Added an in-memory memory store and context assembler.
- Added the chat `Provider`/`ModelRouter` contract and `EchoProvider` from
  PRAXOVELA; PRAXOVELA's model contract package now aliases it.
- Added adapter bridges: `ChatModel`, tool `Gateway`, remote memory `Backend`,
  event `Publisher`, `policy.FuncHook`, and `sandbox.FuncSandbox`.

## [0.2.0] - 2026-10-18

### Added

- Extracted the scheduler engine from PRAXOVELA into `pkg/scheduler` with
  provenance recorded. PRAXOVELA now imports the framework scheduler and keeps
  only a thin product alias.
- Extracted tool-call parsing into `pkg/output` and JSON Schema validation into
  `pkg/tool/schema`. PRAXOVELA now aliases both framework packages.
- Added `pkg/flow` Runnable/Chain/Parallel composition.
- Added `pkg/prompt` template and chat-template interpolation.
- Added `pkg/retriever` Document/Retriever contracts.

### Changed

- Module path is `github.com/axisvela/praxo-core` (no major suffix while 0.x).

## [0.1.0] - 2026-10-18

### Added

- MIT-licensed framework baseline.
- Model, tool, memory, event, scheduler, policy, sandbox, and agent primitives.
- Minimal governed agent loop with tool calls, event emission, and policy hooks.
- Echo example and framework documentation.
