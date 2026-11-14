# Checkpoint Store

This example uses published NuGet `Praxo.Core==0.8.0` to keep checkpoint
storage application-owned while using the SDK allowlist for payload encoding.

`CheckpointAllowlist` accepts only registered payload types. The `MemoryStore`
is a teaching implementation: it keeps the latest record per session.
Production stores should add durable persistence, tenant-scoped access,
encryption, retention, and recovery policy.

## Run the deterministic check

No endpoint is required:

```bash
dotnet run -- --test
```

Expected output:

```text
checkpoint test: ok
```

## Boundaries

- Core owns the checkpoint contract and allowlist encoding.
- The application owns storage, retention, tenancy, and recovery.
- The allowlist rejects unregistered payload types with
  `CHECKPOINT_TYPE_NOT_ALLOWED`.
