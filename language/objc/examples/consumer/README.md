# Independent Objective-C Consumer

This starter uses a deterministic model and an in-memory tool. It does not use
the network or a model service.

macOS with Apple Foundation:

```bash
clang -fobjc-arc -fblocks -Ilanguage/objc/src \
  language/objc/examples/consumer/consumer.m \
  language/objc/src/PraxoJSON.m language/objc/src/PraxoJsonSchema.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoAgent.m \
  -framework Foundation -o build/objc-consumer
./build/objc-consumer
```

GNUstep (Linux or Windows) adds the runtime flags used by
`language/objc/run-tests.py`:

```bash
clang -fobjc-arc -fblocks -fobjc-runtime=gnustep-2.0 -fuse-ld=lld \
  -Ilanguage/objc/src \
  language/objc/examples/consumer/consumer.m \
  language/objc/src/PraxoJSON.m language/objc/src/PraxoJsonSchema.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoAgent.m \
  -lgnustep-base -lobjc -lstdc++ -o build/objc-consumer
./build/objc-consumer
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model requests `record(target)`. The agent has an explicit tool scope
(`toolSelection` and `allowedTools`). The unsafe target is rejected with
`AGENT_POLICY_DENIED` in the tool invocation seam before the counter changes,
and the program exits nonzero if either case is wrong.

The agent exposes an argument-aware policy callback and a before-tool interrupt
seam. This example keeps its target rule in the tool invocation seam and uses the
tool scope for name-level restriction to show defense in depth. See
[`../hitl/`](../hitl/) for an approval example. It is an integration starting
point, not a production security profile. Identity, durable approvals,
isolation, and effect reconciliation remain the application's responsibility.
