# PRAXO-CORE

[English](README.md) | [简体中文](README.zh-CN.md)

[![CI](https://github.com/axisvela/praxo-core/actions/workflows/ci.yml/badge.svg)](https://github.com/axisvela/praxo-core/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-axisvela.github.io-blue)](https://axisvela.github.io/praxo-core/)
[![Go Reference](https://pkg.go.dev/badge/github.com/axisvela/praxo-core/v2.svg)](https://pkg.go.dev/github.com/axisvela/praxo-core/v2)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**An embeddable MIT-licensed agent framework with explicit policy controls,
checkpoints, and event tracing.**

Build governed agents inside your own product without rebuilding the agent
loop, model abstraction, tool contracts, or execution boundaries. Use your own
model providers and integrations. AxisVela products are not required.

[Documentation](https://axisvela.github.io/praxo-core/) |
[Quickstart](docs/getting-started/quickstart.md) |
[Language Implementations](docs/languages/index.md) |
[Examples](language/go/examples)

## Go Reference Module

This repository's root Go module is the reference implementation:
`github.com/axisvela/praxo-core/v2`.

```bash
go get github.com/axisvela/praxo-core/v2@v2.11.3
```

The Go Core provides the agent loop, policy hooks, tool contracts, memory,
checkpoints, context compaction, events, streaming, MCP, OpenTelemetry,
retrieval, and delegation. See the
[Go consumer](docs/getting-started/consumer-go.md) and
[Go implementation](docs/languages/go/index.md).

The same repository also ships independent Python, TypeScript, Java, Rust, C#,
R, Ruby, PHP, Elixir, Lua, and other packages. They do not require the Go
runtime.

## Two Paths

Start with the smaller path, then add governance when you need it.

1. **Deterministic embed:** install a published package, use a fixture model,
   register one tool, and run one allow/deny check. Five minutes is a target with
   the toolchain installed, not a measured result. Start with the
   [Go consumer](docs/getting-started/consumer-go.md),
   [Python consumer](docs/getting-started/consumer-python.md), or
   [TypeScript consumer](docs/getting-started/consumer-typescript.md).
2. **Governed acceptance:** add final tool reauthorization, HITL, negative tests,
   and zero-effect denial checks. Read the
   [application integration checklist](docs/guides/application-integration-checklist.md)
   and the [governed reference example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/governed-workspace).

You do not need the full language matrix, evidence taxonomy, or every adapter
before your first run.

## Choose Your Language

| Language | Package | Start |
| --- | --- | --- |
| Go (reference) | `github.com/axisvela/praxo-core/v2` | [Go consumer](docs/getting-started/consumer-go.md) |
| Python | `praxo-core` | [Python consumer](docs/getting-started/consumer-python.md) |
| TypeScript | `@axisvela/praxo-core` | [TypeScript consumer](docs/getting-started/consumer-typescript.md) |
| Java | `com.axisvela:praxo-core` | [Java consumer](docs/getting-started/consumer-java.md) |
| Rust | `praxo-core` | [Rust implementation](docs/languages/rust/index.md) |
| C# | `Praxo.Core` | [C# implementation](docs/languages/csharp/index.md) |
| R | `praxocore` | [R implementation](docs/languages/r/index.md) |
| Ruby | `praxo-core` | [Ruby consumer](docs/getting-started/consumer-ruby.md) |
| PHP | `axisvela/praxo-core` | [PHP consumer](docs/getting-started/consumer-php.md) |
| Elixir | `praxo_core` | [Elixir consumer](docs/getting-started/consumer-elixir.md) |
| Lua | `praxo-core` | [Lua consumer](docs/getting-started/consumer-lua.md) |

See the full [implementation directory](docs/languages/index.md) and the
[dedicated repository index](docs/languages/repositories.md).

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Language Release Index](docs/languages/registry-status.md)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Go Reference Quickstart

Go is the reference implementation; use the language table above for other
runtimes.

```bash
go get github.com/axisvela/praxo-core/v2@v2.11.3
```

First verify the [independent Go consumer](docs/getting-started/consumer-go.md):
create your own application with the published package and run deterministic
allow/deny tests. No source checkout, API key, or model service is required.

Then run the endpoint quickstart from a checkout using Ollama:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
GOWORK=off go run ./language/go/examples/quickstart
```

Or connect an OpenAI-compatible endpoint:

```bash
export PRAXO_BASE_URL=https://api.openai.com/v1
export PRAXO_API_KEY=...
export PRAXO_MODEL=gpt-4o-mini
GOWORK=off go run ./language/go/examples/quickstart
```

Use Go 1.26.11, the tested CI/release toolchain. On PowerShell, set environment
variables with `$env:PRAXO_BASE_URL = "..."` and the same names. The example
demonstrates tools, streamed text, events, and policy. See the
[quickstart guide](docs/getting-started/quickstart.md) for prerequisites.

## Why PRAXO-CORE

- **Explicit governance:** policy hooks, tool authorization, and HITL decisions.
- **Checkpoint and session contracts:** message-history continuation and application-owned recovery, not durable execution.
- **Observable behavior:** structured events and optional OpenTelemetry integration.
- **Provider-neutral embedding:** model, memory, tool, retrieval, and sandbox interfaces.
- **MIT boundary:** optional integrations stay separate from the core framework.

### Implements, Verifies, Requires

**Governed, Embeddable Agent Execution Kernel** describes an embedding boundary,
not a turnkey enterprise security system. The Go reference implements the full
surface; each language implementation declares its own scope and evidence.

| Area | What Core Implements | What Tests Verify | What the Consumer Must Supply |
| --- | --- | --- | --- |
| Governed | Policy hooks, tool authorization and HITL integration | Configured allow/deny and approval paths | Authentication, policy configuration and enforcement; an Agent can run without Policy |
| Sandbox support | Execution contracts and adapters | Contract behavior and selected adapter boundaries | A real isolated runtime and deployment hardening; an interface is not OS isolation |
| Checkpoint and session | Session/checkpoint contracts with message-history continuation | Serialization and scoped recovery fixtures | Durable stores, run-step recovery, effect verification and idempotency; checkpoints are not external transactions or exactly-once guarantees |
| Multilingual | Shared specification and independent implementations | Each language's declared vectors and behavior coverage | Selection against that language's limitations; not assumed Go feature parity |
| Multi-agent | Local subagent delegation | Launch, status, cancel, and optional update suites | Parent-to-child policy/tool-scope narrowing, distributed coordination, and durable orchestration if needed |

See the [test taxonomy](docs/project/test-taxonomy.md) for evidence levels and
the [consumer starters](docs/getting-started/coding-agents.md) for package-level checks.

One Kernel supports three [integration levels](docs/reference/execution-profiles.md):
**Standard Embedding** (existing behavior), **Governed Execution Profile**
(proposed acceptance design with partial evidence), and **Embodied Integration
Profile** (proposed design; AKROVELA's product-owned P1 adapter and deterministic
slice exist, while the E1-E8 pilot has not run). They are not separate
packages or runtime switches. Required governance is enforced by trusted product
entry points and actual effect boundaries, not by a profile name.

It is a framework, not a hosted agent service, vector database, model provider,
or turnkey chat UI. Review the [adoption guide](docs/getting-started/adoption.md),
[security model](docs/security/index.md), and
[framework comparison](docs/project/comparison.md) before choosing it.

## Choose Your Language

Go is the reference implementation. Core implementations share a normative contract in
[`spec/`](spec/README.md), with language-specific APIs and declared limitations.

| Runtime | Start here |
| --- | --- |
| Go | [Install and quickstart](docs/languages/go/index.md) |
| Python | [Python Core](https://axisvela.github.io/praxo-core/languages/python/) |
| TypeScript / JavaScript | [TypeScript Core](https://axisvela.github.io/praxo-core/languages/typescript/), [JavaScript sample](https://axisvela.github.io/praxo-core/languages/javascript/) |
| Java / Kotlin / Scala / Groovy / Clojure | [Java Core](https://axisvela.github.io/praxo-core/languages/java/), [Kotlin](https://axisvela.github.io/praxo-core/languages/kotlin/), [Scala](https://axisvela.github.io/praxo-core/languages/scala/), [Groovy](https://axisvela.github.io/praxo-core/languages/groovy/), [Clojure](https://axisvela.github.io/praxo-core/languages/clojure/) |
| .NET | [C# Core](https://axisvela.github.io/praxo-core/languages/csharp/), [Visual Basic sample](docs/languages/visual-basic/index.md), [F# sample](docs/languages/fsharp/index.md) |
| C / OpenCL | [C Core](https://axisvela.github.io/praxo-core/languages/c/), [OpenCL sample](https://axisvela.github.io/praxo-core/languages/opencl/) |
| OCaml | [OCaml Core](https://axisvela.github.io/praxo-core/languages/ocaml/) |
| MATLAB / Octave | [MATLAB/Octave Core](https://axisvela.github.io/praxo-core/languages/matlab/) |
| Haskell | [Haskell Core](https://axisvela.github.io/praxo-core/languages/haskell/) |
| Delphi / Free Pascal | [Delphi / Free Pascal Core](https://axisvela.github.io/praxo-core/languages/delphi/) |
| Other languages | [Complete implementation directory](docs/languages/index.md) |

Source releases, package-registry publication, conformance, and production
verification are different states. Follow each language's installation
instructions and [support policy](docs/languages/support.md); do not infer full Go
feature parity or registry availability from a source tag.

Behavior coverage is tiered separately from contract tier. Agent-capable
implementations are Go, Python, TypeScript, Java, Rust, R, and C#; extended
implementations are PHP, C, Fortran, COBOL, Ruby, Elixir, Erlang, C++, and Lua;
other declared implementations are optional. See the
[behavior lab](docs/languages/behavior-lab.md) for current coverage.

## Examples

| Goal | Example |
| --- | --- |
| Run a published package against a real model | [Live model](language/go/examples/live-model) |
| Produce validated JSON | [Python](language/python/examples/structured-output), [TypeScript](language/typescript/examples/structured-output), [Java](language/java/examples/structured-output), [C#](language/csharp/examples/structured-output) |
| Build a read-only workspace agent | [Workspace agent](language/go/examples/workspace-agent) |
| Embed Core in an HTTP service | [Embedded service](language/go/examples/embedded-service) |
| Use a local MCP client | [Python](language/python/examples/mcp), [TypeScript](language/typescript/examples/mcp), [C#](language/csharp/examples/mcp) |
| Call a model with tools and streaming | [Quickstart](language/go/examples/quickstart) |
| Observe approval and denial boundaries | [Governed workspace](language/go/examples/governed-workspace) |
| Resume a run | [Checkpoint](language/go/examples/checkpoint) |
| Gate command execution through policy | [Sandbox](language/go/examples/sandbox) |
| Delegate work | [Multi-agent](language/go/examples/multiagent) |
| Embed with your own adapters | [Integrator](language/go/examples/integrator) |

Task-oriented and language-organized catalogs:
[docs Examples](docs/getting-started/examples.md) and
[language/go/examples/README.md](language/go/examples/README.md).

## Scenario Tutorials and Reference Applications

Scenario tutorials are bounded teaching slices. Reference applications are
portfolio integrations: source implementations exist, while end-to-end portfolio
acceptance remains tracked in the roadmap.

### Scenario Tutorials

| Scenario | Language | Tutorial |
| --- | --- | --- |
| SE-01 Full-stack development | Go | [fullstack-workspace](language/go/Tutorial/fullstack-workspace) |
| SE-02 Bug diagnosis and repair | Python | [bug-repair](language/python/Tutorial/bug-repair) |
| SE-03 Legacy refactoring and migration | Java | [legacy-migration](language/java/Tutorial/legacy-migration) |
| SE-04 Test generation | C# | [test-generation](language/csharp/Tutorial/test-generation) |
| SE-05 Code review and security audit | Go | [evidence-vault](language/go/Tutorial/evidence-vault), [soc-alert-triage](language/go/Tutorial/soc-alert-triage) |
| SE-06 AIOps RCA and remediation | Erlang | [aiops-rca](language/erlang/Tutorial/aiops-rca), [otp-recovery](language/erlang/Tutorial/otp-recovery) |
| SE-07 Cloud and FinOps governance | Ruby | [finops-review](language/ruby/Tutorial/finops-review) |
| SE-08 API orchestration | PHP | [api-orchestration](language/php/Tutorial/api-orchestration) |
| OP-01 Service desk | C# | [internal-service-desk](language/csharp/Tutorial/internal-service-desk) |
| OP-03 Knowledge maintenance | Python | [office-qa](language/python/Tutorial/office-qa) |
| OP-04 Cross-system RPA | Java | [rpa-reconciliation](language/java/Tutorial/rpa-reconciliation) |
| OP-05 Recruiting match | Ruby | [recruiting-match](language/ruby/Tutorial/recruiting-match) |
| OP-06 Employee onboarding | Dart | [onboarding-plan](language/dart/Tutorial/onboarding-plan) |
| OP-07 Executive brief | R | [executive-brief](language/r/Tutorial/executive-brief) |

Full lists: [100 candidate agent scenarios](docs/getting-started/agent-scenarios.md)
and the [unified Tutorial Catalog](docs/getting-started/tutorial-catalog.md).

### Reference Applications

| Priority | Language | Application | Status |
| --- | --- | --- | --- |
| 1 | PHP | [Drupal/Laravel content portal](language/php/application) | Source implementation; acceptance pending |
| 2 | Java | [Spring Boot commerce](language/java/application) | Source implementation; acceptance pending |
| 3 | Elixir / Erlang | [OTP real-time operations](language/elixir/application), [Erlang](language/erlang/application) | Source implementations; acceptance pending |
| 4 | Go | [Cloud and DevOps](language/go/application) | Source implementation; acceptance pending |
| 5 | C++ / Rust | [Industrial/embedded](language/cpp/application), [Systems/edge](language/rust/application) | Source implementations; acceptance pending |
| 6 | COBOL | [Batch exception analysis](language/cobol/application) | Source implementation; acceptance pending |
| 7 | Julia | [Scientific computing](language/julia/application) | Source implementation; acceptance pending |
| 8 | Ruby | [Rails back-office](language/ruby/application) | Source implementation; acceptance pending |

See the [reference application portfolio](docs/project/roadmap.md#reference-application-portfolio)
for acceptance criteria and current limits.

## Repository Map

| Location | Purpose |
| --- | --- |
| [`pkg/`](pkg) | Public Go framework APIs |
| [`adapters/`](adapters) | Optional model, protocol, telemetry, and runtime integrations |
| [`language/`](language/README.md) | Independent language Core source, builds, tests, and API references |
| [`bindings/`](bindings/README.md) | Shell and PowerShell runtime bridges |
| [`spec/`](spec) | Normative wire contract, vectors, and parity inventories |
| [`language/go/examples/`](language/go/examples) | Runnable integration examples |
| [`docs/`](docs) | Public documentation grouped by user task |

Go module paths remain unchanged. Language sources have moved under `language/` and `bindings/`; Go examples
are under `language/go/examples/`; see the [source migration guide](docs/project/repository-layout.md).

## Framework and Ecosystem

PRAXO-CORE is an independent MIT-licensed framework.

Connect models, memory, events, retrieval, and policy through your own adapters
or [optional AxisVela integrations](docs/integrations/ecosystem.md). See the
[adapter directory](docs/integrations/index.md) for module scope and limitations.

## Releases and Contributing

Core `2.11.3` is the current release. It adds scenario-tutorial and
reference-application lists to this README and refreshes the public registry and
release documentation for the current published versions. It does not change the
exported `pkg/...` API or wire contract.

The earlier `2.9.0` fixed the Go memory recall role: recalled content is injected
as untrusted user data with frame/source labels instead of a system message, and
assistant-written memory records carry `source` and `trust` metadata. That release
added two-run regressions without changing the exported `pkg/...` API or wire
shape. Optional adapters and Core implementations are versioned independently.

- [Latest release notes](docs/releases/2.11.3.md)
- [Release history](docs/releases/index.md)
- [Language Release Index](docs/languages/registry-status.md)
- [Compatibility policy](docs/project/compatibility-policy.md)
- [v2 migration](docs/project/migration-v2.md)
- [Public roadmap](ROADMAP.md)
- [Contributing](CONTRIBUTING.md)
- [Security reporting](SECURITY.md)

GitHub Latest Release represents only the Go Reference Core (`vX.Y.Z`). Language
and adapter releases use independent tags and registry versions, not Latest.

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>

## License

MIT. See [LICENSE](LICENSE) and [provenance](docs/project/provenance.md).
