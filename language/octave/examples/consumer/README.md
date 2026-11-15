# Independent Octave Consumer

Octave reuses the shared MATLAB/Octave example at
`language/matlab/examples/consumer/consumer_example.m`. The `run.m` wrapper adds
the shared Core and example paths, then runs the same deterministic allow/deny
check.

From the repository root:

```bash
octave-cli language/octave/examples/consumer/run.m
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model requests `record(target)`. The agent has an explicit tool scope and
the application policy allows only `record` for the `public` target. The unsafe
target is rejected before the effect counter changes. It is an integration
starting point, not a production security profile. Identity, durable approvals,
isolation, and effect reconciliation remain the application's responsibility.

See [`../../../matlab/examples/consumer/README.md`](../../../matlab/examples/consumer/README.md)
for the policy-hook limitation shared by MATLAB and Octave.
