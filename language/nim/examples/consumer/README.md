# Independent Nim Consumer

This starter uses a deterministic model and an in-memory tool. It does not use
the network or a model service. Run it from the repository root:

```bash
nim r --path:language/nim/src language/nim/examples/consumer/consumer.nim
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model requests `record(target)`. The agent has an explicit tool scope
(`allowedTools = @["record"]`) and a policy that allows only `model.generate`
and `tool.invoke`. The unsafe target is rejected with `AGENT_POLICY_DENIED`
before the effect counter changes. The program exits nonzero if either case is
wrong.

The Nim policy callback receives only the action kind, so this example enforces
the argument-level rule (`target == "public"`) inside the tool invocation seam
and raises `AGENT_POLICY_DENIED` before any effect. It is an integration
starting point, not a production security profile. Identity, durable approvals,
isolation, and effect reconciliation remain the application's responsibility.
