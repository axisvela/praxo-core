# Long-Running Operations

This recipe shows how an application can expose a remote long-running operation
through Core tools without confusing the agent Run with the remote operation.

Core owns the local Run, tool invocation, policy, and checkpoint projections. The
remote execution system owns the operation ID, accepted/running state, cancel
confirmation, and final effect evidence. They are related by stable references,
not one shared state machine.

## Required Distinctions

| Concept | Meaning |
| --- | --- |
| Run canceled | The local agent loop stopped; the remote operation is not necessarily stopped |
| Cancel requested | A request was sent to the execution authority; cancellation is not confirmed |
| Cancel confirmed | The execution authority reports the operation stopped |
| Accepted | The execution authority accepted the operation |
| Completed | The execution authority reports the operation finished |
| Effect verified | Environment or business evidence confirms the expected effect |

Do not collapse these into one boolean. In particular, a `Run` error does not
prove that the remote operation failed, and a completion event does not prove a
business effect committed.

## Pattern

1. Use a stable business idempotency key. A new Run ID or model tool-call ID is
   not automatically suitable.
2. Submit through a tool; persist the returned operation reference.
3. On a lost response or restart, query the execution authority by the
   idempotency key or operation ID before submitting again.
4. Send cancellation separately and record the authority's confirmation.
5. Keep final effect evidence in the executing system or an effect ledger.
6. Do not claim exactly-once from a checkpoint or an in-process deduplication
   map.

## Tested Example

The runnable example is
[longrunning_test.go](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-go/longrunning_test.go).
From the published-package Go consumer:

```sh
GOWORK=off go test -mod=readonly -run LongRunning -v ./...
```

| Check | Expected outcome |
| --- | --- |
| Duplicate submit with the same key | same operation ID; one effect |
| Lost response recovery | query/submit with the same key returns the existing operation; no duplicate |
| Cancel request | state is `cancel_requested`, not `canceled` |
| Cancel confirmation | authority moves the operation to `canceled` once |
| Run cancellation | local Run stops; remote state remains `accepted`; no false remote-cancel claim |
| File-backed restart | operation, idempotency key, cancel request, and confirmation survive a new service instance |
| Effect verification | `completed` is not `effect_verified`; verification requires evidence and is persisted |

The fixture can persist to a JSON file so restart recovery can be tested. It
still demonstrates the contract shape, not a durable worker, lease/fencing
implementation, or production effect ledger.

## Limits

- The file-backed fixture writes one JSON file directly. It does not provide a
  crash-consistent database, multi-process locking, or retention policy.
- Restart is simulated with a new service instance in the same process, not a
  real process or machine failure.
- In-process or single-file deduplication is not a production exactly-once
  mechanism. A real service must persist the idempotency key and result with
  defined concurrency and retention semantics.
- A status query must go to the authoritative execution system, not a cached
  checkpoint.
- A cancel request is not a cancel confirmation; the execution authority must
  report the final state.
- Effect verification, leases/fencing, reconciliation, and retention belong to
  the execution system or a durable workflow product.
- This recipe does not provide exactly-once execution.

See [governed execution design](../reference/governed-execution.md), the
[security model](../security/index.md), and [when not to use Core](../getting-started/when-not-to-use.md).
