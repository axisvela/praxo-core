# Multi-turn Checkpoint Recovery

This example uses published NuGet `Praxo.Core==0.8.0` to save and restore a
multi-turn conversation across two agent runs. The checkpoint allowlist encodes
the session message history; the store is a teaching in-memory implementation.

```bash
dotnet run --project language/csharp/examples/session-checkpoint
```

Expected output:

```text
restored messages: 4
output: turn 5
```

A checkpoint is a recovery hint, not a transaction or an exactly-once guarantee.
Production applications own durable storage, tenant scoping, retention, and
recovery policy.
