# Checkpoint and Resume

This example shows the product-owned checkpoint boundary:

- a small in-memory `checkpoint.Store`
- saving a completed session snapshot
- loading the latest checkpoint
- resuming by pre-populating `agent.Session.Messages`

```bash
go run ./examples/checkpoint
```

The in-memory store is only a teaching implementation. Production stores should
add durable persistence, tenant-scoped access, encryption, retention, and
recovery policy.

`pkg/checkpoint` intentionally does not ship a store. The framework owns the
contract; the product owns storage and recovery semantics.

## Committed Effects

`EffectCursor` records the last committed effect for a run. The cursor is a
recovery hint, not an idempotency guarantee: the application must key side
effects and keep its own ledger. This example includes a small application-owned
ledger and a test showing that a committed effect is returned from the ledger
after a restart instead of being executed again.

This demonstrates a recovery pattern only. It does not provide exactly-once
delivery, durable leases/fencing, or graph-level recovery; those remain
product/RHEOVELA responsibilities.

## Test

```bash
go test ./examples/checkpoint
```
