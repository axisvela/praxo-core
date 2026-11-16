# Advanced Delegation

This example shows an application-level parent/child agent pattern using
published crates.io `praxo-core@0.9.1`. The parent agent may call a `delegate`
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
direct recording. It does not test automatic permission inheritance, hostile
child scope expansion, shared budgets, or cancellation propagation.

This is not the Go `pkg/agent/delegation` contract. It is an application-level
orchestration pattern; durable workers, remote task queues, retries, and effect
reconciliation remain application responsibilities.
