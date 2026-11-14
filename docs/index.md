# PRAXO-CORE

**An embeddable MIT-licensed agent framework with explicit policy controls,
checkpoints, and event tracing.**

Build agents inside your own product without rebuilding the loop, model
abstraction, tool contracts, or execution boundaries. Use your own providers
and integrations; AxisVela products are not required.

[Quickstart](getting-started/quickstart.md){ .md-button .md-button--primary }
[Choose Your Language](languages/index.md){ .md-button }
[GitHub](https://github.com/axisvela/praxo-core){ .md-button }

## Why PRAXO-CORE

- Control tool execution through explicit policy hooks and approval boundaries.
- Resume work with checkpoints and inspect execution through structured events.
- Embed provider-neutral model, tool, memory, and sandbox contracts.
- Start with Go or choose a language implementation with a documented scope and conformance gate.
- Keep the framework MIT-licensed and optional integrations separate.

## Choose Your Language

PRAXO-CORE is multi-language. Go is the reference implementation; other
implementations have independent packages and declared scope.

| Language | Start |
| --- | --- |
| Go (reference) | [Go consumer](getting-started/consumer-go.md) |
| Python | [Python consumer](getting-started/consumer-python.md) |
| TypeScript | [TypeScript consumer](getting-started/consumer-typescript.md) |
| Java | [Java consumer](getting-started/consumer-java.md) |
| Rust | [Rust implementation](languages/rust/index.md) |
| C# | [C# implementation](languages/csharp/index.md) |
| R | [R implementation](languages/r/index.md) |
| Ruby | [Ruby consumer](getting-started/consumer-ruby.md) |
| PHP | [PHP consumer](getting-started/consumer-php.md) |
| Elixir | [Elixir consumer](getting-started/consumer-elixir.md) |
| Lua | [Lua consumer](getting-started/consumer-lua.md) |

See the [language implementation directory](languages/index.md) and the
[dedicated repository index](languages/repositories.md).

## Go Reference Quickstart

```bash
go get github.com/axisvela/praxo-core/v2@v2.8.0
```

Follow the [quickstart](getting-started/quickstart.md) to run an agent against
Ollama or an OpenAI-compatible endpoint. For other languages, use the table
above; source tags do not imply package-registry availability.

## Find What You Need

| Your goal | Start here |
| --- | --- |
| Evaluate whether it fits your product | [Adoption guide](getting-started/adoption.md) and [comparison](project/comparison.md) |
| Connect a model or external tool | [Adapter directory](integrations/index.md) and [recipes](guides/recipes.md) |
| Understand runtime boundaries | [Architecture](reference/architecture.md) and [security](security/index.md) |
| Build plugins or delegate work | [Plugin guide](guides/plugins.md) and [multi-agent patterns](guides/multi-agent.md) |
| Upgrade an existing integration | [Compatibility](project/compatibility.md) and [release history](releases/index.md) |

## Current Release

Core `2.8.0` is a minor release adding opt-in `RequirePolicy` and
`RequireToolScope` safe-default guards, HITL and multi-turn checkpoint examples,
and a Go discovery mirror.
See the [release notes](releases/2.8.0.md) for changes and limitations, or the
[release overview](releases/index.md) for older versions.

PRAXO-CORE is a framework, not a hosted service or a turnkey chat UI.
[AxisVela integrations](integrations/ecosystem.md) are optional.

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
