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

## Test

```bash
go test ./examples/checkpoint
```
