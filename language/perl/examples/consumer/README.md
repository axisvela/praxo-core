# Perl Consumer

This example uses the source Perl Core with a deterministic model, one registered
`record` tool, an explicit tool scope, and a policy that permits only the
`public` target. It does not use a network or a live model.

Run from the repository root:

```bash
perl language/perl/examples/consumer/consumer.pl
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The allowed call invokes the tool once. The denied call is rejected before
`invoke`, so the in-memory counter stays at zero. The example prints a failure
line and exits nonzero when either check does not hold.

This verifies a deterministic allow/deny path only. It does not prove live-model
quality, authentic identity, durable approvals, isolation, or effect
reconciliation.
