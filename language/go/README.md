# PRAXO-CORE Go Core

Go is the reference implementation of PRAXO-CORE: an embeddable, MIT-licensed
agent execution kernel with explicit policy controls, checkpoints, events, and
tool calling. It runs in-process and does not require a hosted service.

- `SPEC_VERSION`: `0.2.0`
- Source module: `github.com/axisvela/praxo-core/v2@v2.10.0`
- Tier: Core (reference)
- License: MIT
- Go: module declares `1.25.0`; CI and releases use Go `1.26.11`

## Install

```bash
go get github.com/axisvela/praxo-core/v2@v2.10.0
```

## Quickstart

```go
agentInstance, err := agent.New(agent.Options{
    Model: model,
    Tools: tools,
    MaxSteps: 4,
    AllowedTools: []string{"get_time"},
    Policy: policy.FuncHook(authorize),
})
if err != nil {
    return err
}
result, err := agentInstance.Run(ctx, agent.Session{ID: "demo"}, "What time is it?")
```

See [`language/go/examples/quickstart`](../../language/go/examples/quickstart) for a runnable
OpenAI-compatible endpoint with a `get_time(zone)` tool, and
[`language/go/examples/live-model`](language/go/examples/live-model) for the published-package live path.

## Features

- Governed agent loop with policy hooks, final-argument authorization, and HITL.
- Tools, registry, gateways, retries, and parameter schemas.
- Memory, context budgets, middleware, checkpoints, events, and streaming.
- Provider-neutral model adapters and optional MCP, OTel, and workspace seams.
- Shared `spec/` vectors and API snapshots for cross-language conformance.

## Examples

- [`language/go/examples/quickstart`](../../language/go/examples/quickstart): endpoint quickstart.
- [`language/go/examples/live-model`](language/go/examples/live-model): live model with `get_time(zone)`.
- [`language/go/examples/consumer-go`](language/go/examples/consumer-go): published-package allow/deny starter.
- [`language/go/examples/hitl`](../../language/go/examples/hitl): approval and edit reauthorization.
- [`language/go/examples/session-checkpoint`](../../language/go/examples/session-checkpoint): multi-turn checkpoint recovery.
- [`language/go/examples/governed-workspace`](../../language/go/examples/governed-workspace): policy and approval boundaries.
- [`language/go/examples/multiagent`](../../language/go/examples/multiagent): local delegation.
- [`language/go/examples/plugin`](../../language/go/examples/plugin): process plugin host.

## Verify

From the repository root:

```bash
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
```

## Documentation

- [Go Core documentation](https://axisvela.github.io/praxo-core/languages/go/)
- [API reference](https://pkg.go.dev/github.com/axisvela/praxo-core/v2)
- [Specification](../../spec/README.md)
- [Public roadmap](../../ROADMAP.md)

## Tutorials and Reference Applications

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the reference-application portfolio.
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and application paths.
- [Reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio) ([中文](https://axisvela.github.io/praxo-core/zh-CN/project/roadmap/)).
- Language tutorials: [language/go/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial).
- Reference applications: [language/go/application](https://github.com/axisvela/praxo-core/tree/main/language/go/application).

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

