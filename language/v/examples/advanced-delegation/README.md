# V Advanced Delegation

This example shows an application-level parent/child agent pattern. The parent
may call `delegate` but not the child's `record` tool.

```bash
v -o build/praxo-v-delegation language/v/examples/advanced-delegation/delegation.v
./build/praxo-v-delegation
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
```

`governance.v` adds six application-level negative checks: child scope
narrowing, parent/child policy composition, shared sibling budgets, child-count
and depth limits, cancellation before effects, and final-argument
reauthorization.

```bash
v -o build/praxo-v-governance language/v/examples/advanced-delegation/governance.v
./build/praxo-v-governance
```

Expected output:

```text
V advanced delegation governance: 6/6 passed
```

These checks are application-owned. The published Core API does not inherit or
narrow authority automatically. Durable workers, remote queues, retries, and
effect reconciliation remain application responsibilities.
