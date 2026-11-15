# Objective-C Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses `PXRSessionCreate`, `PXRAgentRun`, `PXRMessageWire`, and the checkpoint
allowlist with a teaching in-memory store keyed by session id.

macOS with Apple Foundation:

```bash
clang -fobjc-arc -fblocks -Ilanguage/objc/src \
  language/objc/examples/session-checkpoint/session_checkpoint.m \
  language/objc/src/PraxoJSON.m language/objc/src/PraxoJsonSchema.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoAgent.m \
  -framework Foundation -o build/objc-session-checkpoint
./build/objc-session-checkpoint
```

GNUstep (Linux or Windows) adds the runtime flags used by
`language/objc/run-tests.py`:

```bash
clang -fobjc-arc -fblocks -fobjc-runtime=gnustep-2.0 -fuse-ld=lld \
  -Ilanguage/objc/src \
  language/objc/examples/session-checkpoint/session_checkpoint.m \
  language/objc/src/PraxoJSON.m language/objc/src/PraxoJsonSchema.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoAgent.m \
  -lgnustep-base -lobjc -lstdc++ -o build/objc-session-checkpoint
./build/objc-session-checkpoint
```

Expected output:

```text
restored messages: 4
output: turn 5
```

The second turn runs against the first checkpoint, then the updated history is
saved and reloaded for the third turn. The program exits nonzero if any turn or
restored count is wrong, so it is also a deterministic self-check. A checkpoint
is a recovery hint, not a transaction or an exactly-once guarantee.
