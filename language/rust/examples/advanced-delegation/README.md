# Advanced Delegation

This example shows an application-level parent/child agent pattern using
published crates.io `praxo-core@0.11.1`. The parent agent may call a `delegate`
tool but not the child's `record` tool. The delegate tool runs a child agent
with its own tool scope, policy, and fixture model.

```bash
cargo run
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
```

The example is deterministic and does not need a model endpoint. It verifies
that the child effect runs once and a separately configured parent policy denies
direct recording.

The `governance` binary adds application-level negative checks for hostile child
scope expansion, policy composition, depth and child limits, shared sibling
budgets, cancellation before effects, and final-argument reauthorization:

```bash
cargo run --bin governance
```

These checks are application-owned; the published Core API does not inherit or
narrow authority automatically.

This is not the Go `pkg/agent/delegation` contract. It is an application-level
orchestration pattern; durable workers, remote task queues, retries, and effect
reconciliation remain application responsibilities.
