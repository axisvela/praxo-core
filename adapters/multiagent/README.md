# Multi-Agent Composition

`adapters/multiagent` is an optional supervisor and sequential delegation layer
over `pkg/agent/delegation`. It does not add a graph or durable workflow
runtime to the core.

```bash
go get github.com/axisvela/praxo-core/adapters/multiagent@v0.2.0
```

```go
supervisor := multiagent.Supervisor{
    Runner:  runner,
    Timeout: 30 * time.Second,
}

outputs, err := supervisor.Run(ctx, "session-1", []multiagent.Worker{
    {Name: "researcher", AgentID: "research", Prompt: "find the status"},
    {Name: "writer", AgentID: "write", Prompt: "write the report"},
})
```

## Patterns

- `Run`: launch workers in parallel and aggregate outputs by worker name.
  `MaxConcurrency` caps how many workers run at once.
- `Sequential`: run workers in order and pass the previous output to the next
  worker as `Context["previous"]`.
- Completion is event-driven through `delegation.SubagentManager.Wait`;
  `Supervisor.PollInterval` is retained but ignored.

Worker names must be unique. `AgentID` selects the runner inside the product
router. The caller owns the `delegation.SubagentRunner`, policy, events,
credentials, and child-agent construction.

## Boundaries

- This is delegation composition, not a graph engine.
- It is not durable; a process restart does not recover tasks.
- Graph/subgraph execution, durable recovery, and graph-level interrupts belong
  to RHEOVELA or the product runtime.
- Timeouts cancel outstanding child contexts and return `ErrTimeout`.
- Use `examples/multiagent` for the dependency-free delegation demo and
  `docs/guides/multi-agent.md` for the full boundary description.

## Test

```bash
cd adapters/multiagent
GOWORK=off go test ./...
```
