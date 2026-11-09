# Durable Start and Uncertain Execution

Evidence level: L4 application recipe. The execution journal in `execution.go`
demonstrates an application-side persistence boundary; it is not a Core service,
authorization system, workflow engine, effect authority or production database.

## Run the Examples

```sh
go test -mod=readonly -run LongRunningExecution -count=1 -v .
```

The full nested-module `go test ./...` also runs these tests. The recipe still
consumes published PRAXO-CORE 2.7.0, without expanding its public API.

## Ordering

1. Validate key/digest and return a matching existing record on retry. A changed
   digest for the same key rejects; no automatic new operation is created.
2. Persist `admitted` with a copied snapshot before exposing it in memory.
3. Persist `start_intent` before invoking the caller-supplied executor.
4. Record `completed` only for a successful callback with an uncanceled context.
   Callback errors or cancellation after entry retain `unknown`, not no-effect.
5. Reopen `start_intent` as `unknown`. Existing admitted/unknown/completed records
   never automatically invoke the callback again. Query/reconciliation belongs
   to the application and must not manufacture authoritative evidence.

The original long-running service counts simulated submission effects. This
supplement has separate executor-entry assertions; those two counts are not
interchangeable. No exactly-once physical-effect guarantee follows.

## Persistence and Faults

Writes use a unique temporary file, file sync and rename. Memory is published only
after all persistence hooks succeed. Any persistence error poisons that instance;
it rejects work until reopened against committed state. A failure reported after
rename does not imply the write did not commit. A callback panic leaves durable
start intent and a poisoned instance; recovery does not replay it.

Tests inject faults before/after rename at admission, start and finish. A bounded
child test process also exits after each committed boundary. The parent waits
for/reaps that process and verifies recovered state and callback-entry evidence.
These are process-death tests, not proof of sudden-power-loss durability.

## Explicit Limits

- One exclusive journal owner is required. The mutex serializes one instance's
  goroutines only; it does not fence another process or another open instance.
- File sync plus rename does not establish cross-platform power-loss guarantees.
  Parent-directory sync, storage guarantees and distributed fencing are separate.
- There is no rollback/clone resistance, secure monotonic counter or hardware
  attestation. Do not deploy it as an offline consumable-authority ledger.
- The digest is supplied by trusted application assembly; the recipe does not
  compute or authenticate a product request binding or grant.
- Reopening an unstarted admission conservatively returns it without execution.
  Safe continuation would need an explicit separately authorized application path.
- There is no timeout-based refund, hidden retry or claim that context cancellation
  proves remote stop. A hung callback may hold the single-instance mutex.
- Existing SQLite/PostgreSQL lease demonstrations are not silently installed or
  promoted by this supplement. No startup migration or fallback is added.

## Provenance and Consumer Use

The generic patterns were adapted under the owner's 2026-11-09 scoped MIT reuse
authorization from AKROVELA commit
`bc8ef5fd0ae34a81debf9d83a494a467adc46f36`,
`backend/internal/satellite/agent.go`, `journal.go` and `agent_test.go`.
No product package or third-party AGPL-only dependency is imported. AKROVELA's
license remains unchanged; see [license and provenance](../../../docs/project/provenance.md).

Consumers can adapt the copy-on-write, durable-start and fault-test patterns while
retaining their own protocols, resource budgets, tenant scope and authority.
Recipe tests never substitute for consumer integration, trusted-device acceptance
or independent assurance evidence.
