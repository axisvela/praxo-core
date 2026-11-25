# Checkpoint and Continuation Path

PRAXO-CORE provides checkpoint and session contracts. It does not provide
durable execution, exactly-once effects, or crash-step recovery. Use this guide
to choose the smallest correct level for your application instead of treating
every checkpoint as a transaction.

## Three Levels

| Level | What you store | What it supports | What it does not support |
| --- | --- | --- | --- |
| Message-history continuation | Session messages and application metadata | Start a new run with prior conversation history | Resuming the exact step or an in-flight tool call |
| Allowlisted checkpoint store | Serialized payloads using the Core allowlist | Reopen and continue a completed run's state | Concurrent database semantics, approvals, or exactly-once |
| Long-running operation state | Application-owned operation record, lease, verifier receipt, effect status | Submit/status/cancel/recover with effect verification | A Core workflow engine, trusted clock, or external exactly-once |

Move up a level only when the application has that requirement. Most
integrations start at message-history continuation.

## Level 1: Message-History Continuation

Use the session-checkpoint examples:

- Go: [`language/go/examples/session-checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/session-checkpoint)
- Python, TypeScript, Java, C#, Rust, R, Ruby, PHP, Elixir, Lua, and other
  declared languages: `language/<language>/examples/session-checkpoint`

The application stores the session messages and starts a new run with them.
This is useful for a chat or a multi-turn task. It is not recovery of a crashed
run, a pending approval, or a tool call that may have produced an effect.

## Level 2: Allowlisted Checkpoint Store

Use the checkpoint recipe or a language checkpoint example:

- Go recipe: [`language/go/examples/recipes/checkpoint-store-go`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/checkpoint-store-go)
- Language examples: `language/<language>/examples/checkpoint`

The example stores only registered payload types and rejects unregistered
types. A teaching file store uses temp-file + sync + rename and tolerates a
partial temporary file. It is not a concurrent database, a transaction, or an
effect ledger. Scope records by tenant and session, and verify the store's
concurrency and failure behavior for your deployment.

## Level 3: Long-Running Operation State

Use the Go reference recipe when the application needs submit, status, cancel,
recovery, a separate verifier, lease/fencing, or effect reconciliation:

- [`language/go/examples/recipes/long-running-go`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/long-running-go)
- [Long-running operation recipe](long-running-operations.md)

Keep the operation state, lease, verifier, and external effect in the
application. A Run completion is not proof that an external effect occurred.
Cancellation is a request until the application confirms the effect boundary.

## Choosing a Level

| Question | Level |
| --- | --- |
| Do I only need the next turn to see prior messages? | Message-history continuation |
| Do I need to reopen a completed run's serialized state? | Allowlisted checkpoint store |
| Do I need to recover a crashed operation, confirm a cancel, or reconcile an external effect? | Long-running operation state |

Do not use a checkpoint as a lock, transaction, approval store, or exactly-once
mechanism. Do not claim durable execution from a message-history continuation.

## Evidence to Record

Record the package version, application revision, store implementation,
serialization allowlist, tenant/session scope, command, expected result,
observed result, and whether the test used a fake model or a real endpoint.
Include a failure/restart case, not only the happy path.
