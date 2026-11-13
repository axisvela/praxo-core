# Checkpoint Store

This example uses published PyPI `praxo-core==0.6.0` to keep checkpoint storage
application-owned while using the SDK allowlist for payload encoding.

`Allowlist` marshals and unmarshals only registered payload types. The
`MemoryStore` is a teaching implementation: it keeps the latest record per
session. Production stores should add durable persistence, tenant-scoped access,
encryption, retention, and recovery policy.

## Run the deterministic test

No endpoint is required:

```bash
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest test_checkpoint_store.py -v
```

## Boundaries

- Core owns the checkpoint contract and allowlist encoding.
- The application owns storage, retention, tenancy, and recovery.
- The allowlist rejects unregistered payload types with
  `CHECKPOINT_TYPE_NOT_ALLOWED`.
