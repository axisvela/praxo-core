# Multi-Agent Patterns

PRAXO-CORE has a single-agent execution loop and asynchronous subagent
delegation. It does not ship a graph, handoff, supervisor, shared-state, or
agent-registry runtime.

## What Is Built In

- `pkg/agent/delegation.SubagentManager`: launch, check, update, cancel, list
- `SubagentIsolated`: child receives only the request context
- `SubagentFork`: child receives the parent message history
- `SubagentRunner`: product-owned interface for executing a child run
- `flow.Chain` and `flow.Parallel`: generic runnable composition
- Parallel tool execution inside one agent step

## What Is Not Built In

- graph and subgraph execution
- supervisor and handoff orchestration
- shared state or blackboards
- agent registry and dynamic routing
- durable workflow recovery and graph-level interrupts

For durable graph execution, use RHEOVELA or the product runtime. The core keeps
the agent-node/session/stream boundary and does not grow a competing graph
engine.

## Example

[`examples/multiagent`](https://github.com/axisvela/praxo-core/tree/main/examples/multiagent)
runs two subagents asynchronously, aggregates their outputs, and cancels a slow
task.

```go
manager := delegation.NewSubagentManager(router{
    "researcher": agentRunner{agent: researcher},
    "writer":     agentRunner{agent: writer},
})

task, err := manager.Launch(ctx, delegation.SubagentRequest{
    ParentSessionID: "session-1",
    AgentID:         "researcher",
    Prompt:          "find the status",
    Mode:            delegation.SubagentIsolated,
})
```

A product supplies the router and `SubagentRunner`; the framework owns the task
lifecycle and observable state.

## Optional Composition Module

[`adapters/multiagent`](https://github.com/axisvela/praxo-core/tree/main/adapters/multiagent)
adds a small optional layer over `SubagentManager`:

- `Supervisor.Run` launches workers in parallel and aggregates outputs.
- `Supervisor.Sequential` passes each output to the next worker as
  `Context["previous"]`.
- Timeouts cancel outstanding child contexts and return `ErrTimeout`.

It is not a graph or durable workflow runtime and does not change the core API.

## Durable Orchestration with RHEOVELA

Use RHEOVELA when the workflow needs durable graph/subgraph execution, recovery,
leases, or graph-level interrupts. PRAXO-CORE supplies the agent session and
stream boundary; RHEOVELA owns the graph.

[`examples/ecosystem-sdk`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/rheovela)
contains a `rheovela.Runner` recipe:

```go
runner := rheovela.Runner{
    Client:    rheovela.NewClient("http://127.0.0.1:8080"),
    Workflow:  "agent",
    ProjectID: "proj",
    Actor:     "agent-1",
}

instance, err := runner.Start(ctx, session)
err = runner.Step(ctx, instance.InstanceID, "advance", "review")
audit, err := runner.Audit(ctx, instance.InstanceID)
```

### Boundary Checklist

- PRAXO-CORE does not define graph nodes, edges, subgraphs, or graph interrupts.
- RHEOVELA owns graph execution, durable recovery, leases, and routing.
- PRAXO-CORE exposes the agent node/session/stream contract only.
- The product owns task stores, credentials, authorization, and audit retention.
- Use `adapters/multiagent` only for in-process supervisor/sequential delegation.
- Do not claim durable execution for `SubagentManager` or `adapters/multiagent`.

## Choosing a Pattern

| Need | Pattern |
| --- | --- |
| Small number of async child tasks | `SubagentManager` |
| Parent history inherited by child | `SubagentFork` |
| Isolated child context | `SubagentIsolated` |
| Generic sequential/parallel functions | `flow` |
| Durable graph, recovery, interrupts | RHEOVELA |

## Boundaries

- Subagents are child runs, not a multi-agent graph runtime.
- The example is a deterministic demonstration, not production validation.
- PII, credentials, policy, and event sinks remain product-owned per child run.
- Cancellation and failure must be handled by the caller; the manager records
  state and cancels the child context.
