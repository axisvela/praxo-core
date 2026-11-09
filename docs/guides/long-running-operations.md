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

The runnable example is the separate L4 recipe module
[`examples/recipes/long-running-go`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/long-running-go).
From that directory:

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
| Effect receipt | evidence must carry a verifier-issued receipt; forged receipts are rejected and leave the state at `completed` |
| HTTP response loss | commit succeeds but the response is lost; retry with the same key returns the existing operation |
| HTTP restart | a new loopback service loads the file and answers status/recovery queries |
| Cross-process restart | a separate test process serves HTTP; it is killed and restarted with the same file, and the main process recovers the existing operation |
| Partial temp file | a leftover `.tmp` file is ignored; the last committed state and idempotency key remain intact |
| Fencing token | a worker holding an old epoch cannot complete; the new owner increments the epoch and completes once |
| Durable fencing | owner, epoch, and completion survive restart; stale epochs are still rejected |
| Lease expiry | an expired lease cannot complete; a new owner acquires the next epoch |
| Lease renewal | renewal before expiry extends the lease and preserves completion |
| Lease revocation | revocation blocks the old owner; a new owner can reacquire |
| Lease restart | expiry and revocation survive a restart |
| Concurrent writers | two independent file writers can overwrite each other; the boundary test records the lost update and is not a pass |
| Independent verifier process | the execution service calls a separate verifier process and does not hold the signing secret; forged receipts are rejected |
| Bearer/TLS boundary | missing or wrong bearer token is rejected before any effect; a test TLS certificate is used |
| Fault before rename | a simulated crash before the rename boundary leaves the last committed state; the temp file is ignored |
| Fault after rename | a simulated crash after the rename boundary preserves the newly committed state |
| Valid uncommitted temp | a valid but uncommitted temp file does not override the committed file |
| Corrupt committed file | startup fails closed instead of silently starting empty |
| Process crash before rename | the standalone service exits at the commit boundary; restart keeps the last committed state |
| Process crash after rename | the standalone service exits after commit; restart keeps the new operation |

The fixture can persist to a JSON file and expose it over a loopback HTTP service
so response loss and restart can be tested through a real transport boundary. It
still demonstrates the contract shape, not a durable worker, lease/fencing
implementation, or production effect ledger.

## Standalone Service

The example module also builds a standalone service:

```sh
GOWORK=off go build -mod=readonly -o longrunning-service ./cmd/longrunning-service
./longrunning-service -addr 127.0.0.1:8080 -state ./operations.json -token "$PRAXO_TOKEN"
```

It exposes `/healthz`, `/readyz`, and the operation endpoints, supports
`-tls-cert`/`-tls-key`, and shuts down on interrupt. The `cmd` integration test
builds the binary, starts it on a real TCP port, and checks health, readiness,
submit, and status. This is still a local fixture: it has no production identity,
key rotation, database, or deployment automation.

## Limits

- The file store writes a temporary file, syncs it, and renames it over the main
  file. Deterministic tests inject failure before and after the rename boundary,
  verify that a valid uncommitted temp file cannot override committed state, and
  require corrupt committed state to fail closed. This is not a full
  crash-consistency proof: the directory is not synced, OS-level power loss and
  committed-file corruption recovery are not exercised, and concurrent
  multi-process writers remain unsupported.
- The HTTP service is a loopback test fixture. Its bearer token is static and
  its TLS certificate is a test certificate; it has no identity provider, token
  rotation, tenant binding, rate limiting, or production deployment guarantee.
- Restart includes a killed child process with the same file. Process-level crash
  tests exit the standalone service before and after the rename boundary;
  OS-level power loss and committed-file corruption recovery remain untested.
- In-process or single-file deduplication is not a production exactly-once
  mechanism. A real service must persist the idempotency key and result with
  defined concurrency and retention semantics.
- A status query must go to the authoritative execution system, not a cached
  checkpoint.
- A cancel request is not a cancel confirmation; the execution authority must
  report the final state.
- The verifier is a separate loopback process fixture, but it uses a static
  secret and token. A real deployment needs key management, rotation,
  revocation, and an independently operated verification authority.
- The fencing fixture now models lease expiry, renewal, and revocation in a JSON
  file. It still has no coordination service, trusted clock guarantees,
  production lease storage, or concurrent-writer lock. A boundary test records
  that two independent writers can lose an update; use a real lease or
  coordination service for concurrent processes.
- Effect verification, production leases/fencing, reconciliation, and retention
  belong to the execution system or a durable workflow product.
- This recipe does not provide exactly-once execution.

See [governed execution design](../reference/governed-execution.md), the
[security model](../security/index.md), and [when not to use Core](../getting-started/when-not-to-use.md).
