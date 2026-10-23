# PRAXO-CORE

**A public, MIT-licensed agent framework for the AxisVela ecosystem.**

PRAXO-CORE provides the reusable primitives behind PRAXOVELA and other
AxisVela agents: models, tools, memory, events, scheduling, policy,
sandboxing, checkpoints, the runtime plugin plane, and the agent loop.

[Quickstart](quickstart.md){ .md-button .md-button--primary }
[GitHub](https://github.com/axisvela/praxo-core){ .md-button }

## Why PRAXO-CORE

- Small, MIT-licensed runtime boundary for embedding in products
- Provider-neutral model, memory, event, policy, sandbox, and tool contracts
- Governed agent loop with middleware, budgets, checkpoints, and HITL
- Optional OpenAI-compatible and MCP adapters
- First-class seams for the AxisVela ecosystem

## Install

```bash
go get github.com/axisvela/praxo-core/v2@v2.3.0
```

## Explore

- [Quickstart](quickstart.md)
- [2.3.0 release notes](releases/2.3.0.md)
- [2.2.0 release notes](releases/2.2.0.md)
- [2.1.0 release notes](releases/2.1.0.md)
- [Adoption guide](adoption.md)
- [Recipes](recipes.md)
- [Adapter index](adapters.md)
- [Multi-agent patterns](13-multi-agent.md)
- [Comparison with other Go agent frameworks](comparison.md)
- [AxisVela ecosystem integration](12-ecosystem.md)
- [Architecture](01-architecture.md)
- [Primitives](02-primitives.md)
- [Plugin authoring](10-plugin-authoring.md)
- [Security model](08-security.md)
- [中文文档](zh-CN/README.md)

## Status

`2.3.0` is the current core release. The exported `pkg/...` API remains frozen;
2.3.0 adds `SubagentManager.Wait` and `SubagentManager.Prune`. Optional adapters
are versioned independently (`adapters/mcp/v0.3.0`, `adapters/otel/v0.2.0`,
`adapters/anthropic/v0.1.0`, `adapters/gemini/v0.1.0`,
`adapters/harmovela/v0.1.0`, `adapters/a2a/v0.1.0`,
`adapters/multiagent/v0.2.0`). See
[compatibility](05-compatibility.md) and the
[v2 migration guide](11-migration-v2.md).
