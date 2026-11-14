# PRAXO-CORE Go Core

Go is the reference implementation of PRAXO-CORE: an embeddable, MIT-licensed
agent execution kernel with explicit policy controls, checkpoints, events, and
tool calling. It runs in-process and does not require a hosted service.

- `SPEC_VERSION`: `0.2.0`
- Source module: `github.com/axisvela/praxo-core/v2@v2.7.0`
- Tier: Core (reference)
- License: MIT
- Go: module declares `1.25.0`; CI and releases use Go `1.26.11`

## Install

```bash
go get github.com/axisvela/praxo-core/v2@v2.7.0
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

See [`examples/quickstart`](../../examples/quickstart) for a runnable
OpenAI-compatible endpoint with a `get_time(zone)` tool, and
[`examples/live-model`](examples/live-model) for the published-package live path.

## Features

- Governed agent loop with policy hooks, final-argument authorization, and HITL.
- Tools, registry, gateways, retries, and parameter schemas.
- Memory, context budgets, middleware, checkpoints, events, and streaming.
- Provider-neutral model adapters and optional MCP, OTel, and workspace seams.
- Shared `spec/` vectors and API snapshots for cross-language conformance.

## Examples

- [`examples/quickstart`](../../examples/quickstart): endpoint quickstart.
- [`examples/live-model`](examples/live-model): live model with `get_time(zone)`.
- [`examples/consumer-go`](examples/consumer-go): published-package allow/deny starter.
- [`examples/hitl`](../../examples/hitl): approval and edit reauthorization.
- [`examples/session-checkpoint`](../../examples/session-checkpoint): multi-turn checkpoint recovery.
- [`examples/governed-workspace`](../../examples/governed-workspace): policy and approval boundaries.
- [`examples/multiagent`](../../examples/multiagent): local delegation.
- [`examples/plugin`](../../examples/plugin): process plugin host.

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
