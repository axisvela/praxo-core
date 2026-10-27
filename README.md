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
[Examples](examples)

## Start With Go

```bash
go get github.com/axisvela/praxo-core/v2@v2.5.0
```

Run the quickstart from a checkout using Ollama:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
GOWORK=off go run ./examples/quickstart
```

Or connect an OpenAI-compatible endpoint:

```bash
export PRAXO_BASE_URL=https://api.openai.com/v1
export PRAXO_API_KEY=...
export PRAXO_MODEL=gpt-4o-mini
GOWORK=off go run ./examples/quickstart
```

Use Go 1.26.10, the tested CI/release toolchain. On PowerShell, set environment
variables with `$env:PRAXO_BASE_URL = "..."` and the same names. The example
demonstrates tools, streamed text, events, and policy. See the
[quickstart guide](docs/getting-started/quickstart.md) for prerequisites.

## Why PRAXO-CORE

- **Explicit governance:** policy hooks, tool authorization, and HITL decisions.
- **Recoverable execution:** checkpoint and session contracts with resume support.
- **Observable behavior:** structured events and optional OpenTelemetry integration.
- **Provider-neutral embedding:** model, memory, tool, retrieval, and sandbox interfaces.
- **MIT boundary:** optional integrations stay separate from the core framework.

It is a framework, not a hosted agent service, vector database, model provider,
or turnkey chat UI. Review the [adoption guide](docs/getting-started/adoption.md),
[security model](docs/security/index.md), and
[framework comparison](docs/project/comparison.md) before choosing it.

## Choose Your Language

Go is the reference implementation. SDKs share a normative contract in
[`spec/`](spec/README.md), with language-specific APIs and declared limitations.

| Runtime | Start here |
| --- | --- |
| Go | [Install and quickstart](docs/languages/go.md) |
| Python | [Python SDK](https://axisvela.github.io/praxo-core/languages/python/) |
| TypeScript / JavaScript | [TypeScript SDK](https://axisvela.github.io/praxo-core/languages/typescript/), [JavaScript sample](https://axisvela.github.io/praxo-core/languages/javascript/) |
| Java / Kotlin / Scala / Groovy / Clojure | [Java SDK](https://axisvela.github.io/praxo-core/languages/java/), [Kotlin](https://axisvela.github.io/praxo-core/languages/kotlin/), [Scala](https://axisvela.github.io/praxo-core/languages/scala/), [Groovy](https://axisvela.github.io/praxo-core/languages/groovy/), [Clojure](https://axisvela.github.io/praxo-core/languages/clojure/) |
| .NET | [C# SDK](https://axisvela.github.io/praxo-core/languages/csharp/), [Visual Basic sample](docs/languages/visual-basic.md), [F# sample](docs/languages/fsharp.md) |
| C / OpenCL | [C SDK](https://axisvela.github.io/praxo-core/languages/c/), [OpenCL sample](https://axisvela.github.io/praxo-core/languages/opencl/) |
| Other languages | [Complete implementation directory](docs/languages/index.md) |

Source releases, package-registry publication, conformance, and production
verification are different states. Follow each language's installation
instructions and [support policy](docs/languages/support.md); do not infer full Go
feature parity or registry availability from a source tag.

## Examples

| Goal | Example |
| --- | --- |
| Call a model with tools and streaming | [Quickstart](examples/quickstart) |
| Observe approval and denial boundaries | [Governed workspace](examples/governed-workspace) |
| Resume a run | [Checkpoint](examples/checkpoint) |
| Gate command execution through policy | [Sandbox](examples/sandbox) |
| Delegate work | [Multi-agent](examples/multiagent) |
| Embed with your own adapters | [Integrator](examples/integrator) |

## Repository Map

| Location | Purpose |
| --- | --- |
| [`pkg/`](pkg) | Public Go framework APIs |
| [`adapters/`](adapters) | Optional model, protocol, telemetry, and runtime integrations |
| [`language/`](language/README.md) | Independent language SDK source, builds, tests, and API references |
| [`bindings/`](bindings/README.md) | Shell and PowerShell runtime bridges |
| [`spec/`](spec) | Normative wire contract, vectors, and parity inventories |
| [`examples/`](examples) | Runnable integration examples |
| [`docs/`](docs) | Public documentation grouped by user task |

Go module paths remain unchanged. Language sources have moved under `language/`,
`bindings/`, and `examples/`; see the [source migration guide](docs/project/repository-layout.md).

## Framework and Ecosystem

PRAXO-CORE is extracted from PRAXOVELA, but it is a separate MIT-licensed
framework. PRAXOVELA is an AGPL-3.0 runtime product. The framework never imports
product code; credentials and tenant data remain with the integrator.

Connect models, memory, events, retrieval, and policy through your own adapters
or [optional AxisVela integrations](docs/integrations/ecosystem.md). See the
[adapter directory](docs/integrations/index.md) for module scope and limitations.

## Releases and Contributing

Core `2.5.0` adds the conformance package and local VFS hardening. Optional
adapters and SDKs are versioned independently.

- [Latest release notes](docs/releases/2.5.0.md)
- [Release history](docs/releases/index.md)
- [Compatibility policy](docs/project/compatibility-policy.md)
- [v2 migration](docs/project/migration-v2.md)
- [Public roadmap](ROADMAP.md)
- [Contributing](CONTRIBUTING.md)
- [Security reporting](SECURITY.md)

## License

MIT. See [LICENSE](LICENSE) and [provenance](docs/project/provenance.md).
