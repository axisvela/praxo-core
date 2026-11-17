# Multi-Agent Delegation Example

This example uses `pkg/agent/delegation` to run two subagents asynchronously and
aggregate their results.

```bash
go run ./examples/multiagent
```

It demonstrates:

- a router that maps agent IDs to runners
- `SubagentManager` launch/wait/cancel
- isolated subagent sessions
- result aggregation

Application-level governance tests in `governance_test.go` cover child scope
narrowing, depth and child limits, shared sibling budgets, cancellation without
effects, and final-argument reauthorization. They are examples, not a Core
delegation profile; the parent application still owns policy composition,
budget storage, and effect reconciliation.

This is **delegation**, not a graph/handoff runtime. PRAXO-CORE keeps the
single-agent loop and exposes subagents as child runs; durable graph execution
belongs to RHEOVELA or the product runtime.

See [Multi-agent patterns](../../docs/guides/multi-agent.md) for the supported
patterns and boundaries.
