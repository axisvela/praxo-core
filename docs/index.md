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

| Language | You can build today | Start |
| --- | --- | --- |
| Go (reference) | Published module, governed allow/deny, real-model chain, reference examples | [Go consumer](getting-started/consumer-go.md) |
| Python | Published package, governed acceptance, HITL, streaming, MCP | [Python consumer](getting-started/consumer-python.md) |
| TypeScript | Published package, governed acceptance, HITL, streaming, MCP | [TypeScript consumer](getting-started/consumer-typescript.md) |
| Java | Published package, governed acceptance, HITL, streaming, MCP | [Java consumer](getting-started/consumer-java.md) |
| Rust | Published crate, HITL, streaming, MCP, OIDC service example | [Rust implementation](languages/rust/index.md) |
| C# | Published NuGet package, HITL, streaming, MCP, OIDC service | [C# implementation](languages/csharp/index.md) |
| R | r-universe source release, HITL, streaming, analytics workflows | [R implementation](languages/r/index.md) |
| Ruby | Published gem, allow/deny starter, HITL, streaming, OIDC service | [Ruby consumer](getting-started/consumer-ruby.md) |
| PHP | Published package, allow/deny starter, HITL, streaming, OIDC service | [PHP consumer](getting-started/consumer-php.md) |
| Elixir | Published package, allow/deny starter, HITL, streaming, process plugins | [Elixir consumer](getting-started/consumer-elixir.md) |
| Lua | Published rock, allow/deny starter, HITL, streaming | [Lua consumer](getting-started/consumer-lua.md) |

These descriptions are buildable paths, not full feature parity or production
readiness. Registry versions may lag source tags; check [registry publication
status](languages/registry-status.md) before installing. See the
[language implementation directory](languages/index.md#what-you-can-build-today)
and the [dedicated repository index](languages/repositories.md).

## Go Reference Quickstart

```bash
go get github.com/axisvela/praxo-core/v2@v2.11.3
```

Follow the [quickstart](getting-started/quickstart.md) to run an agent against
Ollama or an OpenAI-compatible endpoint. For other languages, use the table
above; source tags do not imply package-registry availability.

## Find What You Need

| Your goal | Start here |
| --- | --- |
| Choose a task and the path layer that proves it | [Start Here task-to-path table](getting-started/index.md#task-to-path-table) |
| Evaluate whether it fits your product | [Adoption guide](getting-started/adoption.md) and [comparison](project/comparison.md) |
| Connect a model or external tool | [Adapter directory](integrations/index.md) and [recipes](guides/recipes.md) |
| Understand runtime boundaries | [Architecture](reference/architecture.md) and [security](security/index.md) |
| Build plugins or delegate work | [Plugin guide](guides/plugins.md) and [multi-agent patterns](guides/multi-agent.md) |
| Upgrade an existing integration | [Compatibility](project/compatibility.md) and [release history](releases/index.md) |

## Current Release

Core `2.11.3` is a documentation release. It adds scenario-tutorial and
reference-application lists to the root README and refreshes the public registry
and release documentation for the current published versions. It does not change
the exported `pkg/...` API or the shared wire contract.
See the [release notes](releases/2.11.3.md) for changes and limitations, or the
[release overview](releases/index.md) for older versions.

PRAXO-CORE is a framework, not a hosted service or a turnkey chat UI.
[AxisVela integrations](integrations/ecosystem.md) are optional.

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
