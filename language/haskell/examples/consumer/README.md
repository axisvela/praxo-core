# Independent Haskell Consumer

This starter uses a deterministic model and an in-memory tool. It does not use
the network or a model service. Run it from the repository root with GHC
installed:

```bash
runghc -ilanguage/haskell/src language/haskell/examples/consumer/consumer.hs
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model requests `record(target)`. The agent has an explicit tool scope
(`allowedTools = ["record"]`) and a policy that allows only `model.generate` and
`tool.invoke`; the unsafe target is rejected before the tool's counter is
incremented. The program exits nonzero if either case is wrong.

The Haskell policy hook receives only the action kind, so this example enforces
the argument-level rule (`target == "public"`) inside the tool invocation seam
and returns `AGENT_POLICY_DENIED` before any effect. It is an integration
starting point, not a production security profile. Identity, durable approvals,
isolation, and effect reconciliation remain the application's responsibility.
