# PRAXO-CORE

**An embeddable MIT-licensed agent framework with explicit policy controls,
checkpoints, and event tracing.**

Build agents inside your own product without rebuilding the loop, model
abstraction, tool contracts, or execution boundaries. Use your own providers
and integrations; AxisVela products are not required.

[Quickstart](getting-started/quickstart.md){ .md-button .md-button--primary }
[Choose Your Language](sdks/index.md){ .md-button }
[GitHub](https://github.com/axisvela/praxo-core){ .md-button }

## Why PRAXO-CORE

- Control tool execution through explicit policy hooks and approval boundaries.
- Resume work with checkpoints and inspect execution through structured events.
- Embed provider-neutral model, tool, memory, and sandbox contracts.
- Start with Go or choose an SDK with a documented scope and conformance gate.
- Keep the framework MIT-licensed and optional integrations separate.

## Start With Go

```bash
go get github.com/axisvela/praxo-core/v2@v2.5.0
```

Follow the [quickstart](getting-started/quickstart.md) to run an agent against
Ollama or an OpenAI-compatible endpoint. For other languages, start with the
[SDK directory](sdks/index.md); source tags do not imply package-registry availability.

## Find What You Need

| Your goal | Start here |
| --- | --- |
| Evaluate whether it fits your product | [Adoption guide](getting-started/adoption.md) and [comparison](project/comparison.md) |
| Connect a model or external tool | [Adapter directory](integrations/index.md) and [recipes](guides/recipes.md) |
| Understand runtime boundaries | [Architecture](reference/architecture.md) and [security](security/index.md) |
| Build plugins or delegate work | [Plugin guide](guides/plugins.md) and [multi-agent patterns](guides/multi-agent.md) |
| Upgrade an existing integration | [Compatibility](project/compatibility.md) and [release history](releases/index.md) |

## Current Release

Core `2.5.0` adds the conformance package and hardens local VFS path validation.
See the [release notes](releases/2.5.0.md) for changes and limitations, or the
[release overview](releases/index.md) for older versions.

PRAXO-CORE is a framework, not a hosted service or a turnkey chat UI. It is
extracted from PRAXOVELA; [AxisVela integrations](integrations/ecosystem.md) are optional.
