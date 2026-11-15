# Objective-C HITL Approval

This example demonstrates a write tool that requires human approval:

- approve the original `write_note(text="hello", visibility="public")` call;
- edit the decision to `visibility="private"`, which is reauthorized and denied
  before the tool runs.

macOS with Apple Foundation:

```bash
clang -fobjc-arc -fblocks -Ilanguage/objc/src \
  language/objc/examples/hitl/hitl.m \
  language/objc/src/PraxoJSON.m language/objc/src/PraxoJsonSchema.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoAgent.m \
  language/objc/src/PraxoHitl.m \
  -framework Foundation -o build/objc-hitl
./build/objc-hitl
```

GNUstep (Linux or Windows) adds the runtime flags used by
`language/objc/run-tests.py`:

```bash
clang -fobjc-arc -fblocks -fobjc-runtime=gnustep-2.0 -fuse-ld=lld \
  -Ilanguage/objc/src \
  language/objc/examples/hitl/hitl.m \
  language/objc/src/PraxoJSON.m language/objc/src/PraxoJsonSchema.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoAgent.m \
  language/objc/src/PraxoHitl.m \
  -lgnustep-base -lobjc -lstdc++ -o build/objc-hitl
./build/objc-hitl
```

Expected output:

```text
approve: written; effects=1
edit: policy rejected; effects=0
```

The model is a deterministic fixture so the approval path is reproducible. The
agent has an explicit tool scope and an argument-aware policy. The edited
`visibility="private"` arguments are reauthorized and denied with
`AGENT_POLICY_DENIED` before the effect counter changes, and the program exits
nonzero if either case is wrong. To use a live model, replace `FixtureModel`
with `PXROpenAIModelCreate` and prompt the model to call `write_note` with
`text` and `visibility`.

The example is an integration starting point, not a production approval store.
Durable approvals, identity, and effect reconciliation remain the application's
responsibility.
