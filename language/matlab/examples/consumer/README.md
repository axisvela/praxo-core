# Independent MATLAB/Octave Consumer

This starter uses a deterministic model and an in-memory tool. It does not use
the network or a model service. Run it from the repository root:

```bash
octave-cli --path language/matlab-octave-core \
  --path language/matlab/examples/consumer --eval consumer_example
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model requests `record(target)`. The agent has an explicit tool scope
(`allowedTools` and `toolSelection`), and the application policy allows only
`record` for the `public` target. The unsafe target is rejected before the
effect counter changes, and the program exits nonzero if either case is wrong.

The shared MATLAB/Octave agent loop validates `requirePolicy` but does not yet
dispatch argument-aware policy hooks. This example therefore evaluates the same
`authorize` function inside the tool invocation seam, before the counter
changes, and records `AGENT_POLICY_DENIED` in the run failure. It is an
integration starting point, not a production security profile. Identity,
durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
