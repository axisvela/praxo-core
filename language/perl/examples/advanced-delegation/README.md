# Perl Advanced Delegation

This example shows an application-level parent/child agent pattern. The parent
agent may call a `delegate` tool but not the child's `record` tool. The delegate
tool runs a child agent with its own tool scope, policy, and deterministic model.

```bash
perl language/perl/examples/advanced-delegation/delegation.pl
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
```

`test_governance.pl` adds application-level negative checks for hostile child
scope expansion, parent/child policy composition, shared sibling budgets, depth
and child limits, cancellation before effects, and final-argument
reauthorization:

```bash
perl language/perl/examples/advanced-delegation/test_governance.pl
```

Expected output:

```text
Perl advanced delegation governance: 6/6 passed
```

The example is deterministic and does not need a model endpoint. These checks are
application-owned; the published Core API does not inherit or narrow authority
automatically. Durable workers, remote task queues, retries, and effect
reconciliation remain application responsibilities.
