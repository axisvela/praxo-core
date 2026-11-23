# Go logistics checkpoint and resume

A scoped logistics tutorial over the Go reference Core that shows a two-run
workflow across a checkpoint. The first run assesses a fixed `shipment-100` and
saves a `checkpoint.Checkpoint`. After a simulated application approval, the
second run restores the checkpoint messages, drafts a review-only reroute without
re-reading the shipment, and saves an extended checkpoint. The source and model
are deterministic fixtures. This tutorial does not connect a real logistics
system, run a durable database, execute exactly-once effects, apply a route change
or call a live model.

Run from the repository root:

```bash
go run ./language/go/Tutorial/logistics-checkpoint --test
go run ./language/go/Tutorial/logistics-checkpoint
go run ./language/go/Tutorial/logistics-checkpoint --simulate-failure
```

Expected test output:

```text
assess: shipment-100 stage=assessed reads=1 drafts=0
resume: shipment-100 stage=reroute_drafted reads=1 drafts=1 route_writes=0
checkpoint: restored and extended without re-reading
failure: SHIPMENT_SOURCE_UNAVAILABLE reads=1
```

The package also has a Go test
(`go test ./language/go/Tutorial/logistics-checkpoint`).

## Path

1. Run 1 assesses `shipment-100`: `read_shipment` returns origin, destination,
   status `delayed` and ETA `38`, and the model reports `stage=assessed`. The
   application serializes the transcript into a checkpoint (JSON round-trip in an
   in-memory store) with `status=awaiting_approval`.
2. The application treats an approval as application-owned state (not modeled
   here) and resumes the session from the checkpoint messages.
3. Run 2 sees the persisted shipment tool result, so it calls `draft_reroute`
   once instead of re-reading. `reads` stays at `1`; `drafts` reaches `1`. The
   model reports `stage=reroute_drafted` and the checkpoint grows to `cp-2`.

The application owns durable storage, approval records, effect reconciliation and
any real route change.

## Scope

This is source, local fixture and local checkpoint-round-trip evidence. The store
is in-memory with JSON serialization; it is not a database, concurrent store,
lease service or exactly-once proof. It does not establish a real logistics
runtime, live provider, public hosting or independent adoption. Tool names and
report fields are tutorial-local and are not Core or wire API.
