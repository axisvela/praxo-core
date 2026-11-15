# Independent Julia Consumer

This starter uses a deterministic model and an in-memory tool. It does not use
the network or a model service. From the repository root, install the declared
`JSON` dependency once:

```bash
julia --project=language/julia -e 'using Pkg; Pkg.instantiate()'
```

Then run:

```bash
julia --project=language/julia language/julia/examples/consumer/consumer.jl
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model requests `record(target)`. The agent has an explicit tool scope
(`allowed_tools = ["record"]`) and a policy that allows only `model.generate`
and a `record` call for the `public` target. The rejected call raises
`PraxoError` with code `AGENT_POLICY_DENIED` before the counter changes. The
program exits nonzero if either case is wrong.

Tool registration calls `PraxoCore.AgentRuntime.register!` directly because the
`ToolRegistry` method is not currently exported through the `PraxoCore`
shorthand.

It is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
