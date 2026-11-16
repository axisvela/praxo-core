# Consumer Test Template

Copy the checks that match your application's risk tier into the consumer
repository. Do not copy the entire Core test matrix. The runnable consumer
starters and structured-output examples show the same patterns in code.

## Minimal Checks for Every Application

Keep these checks where your integration lives:

1. the application starts and reaches the model adapter;
2. an allowed tool call completes once;
3. a denied call produces no tool effect;
4. a missing policy or required dependency fails closed;
5. the package version in the lockfile matches the intended release.

Go consumer example:
[`language/go/examples/consumer-go/governed_test.go`](https://github.com/axisvela/praxo-core/blob/main/language/go/examples/consumer-go/governed_test.go).

## Memory and Context Trust

Add these checks when the application enables memory recall or injects
retrieved text into a prompt:

- write a record in one run, start a fresh agent, recall it in a second run, and
  assert the recalled content is not a `system` message;
- assert the recall block identifies untrusted historical data and, when
  available, the source/frame;
- store a malicious instruction as assistant output, a tool result, and an
  external record; assert none of them can raise their own instruction
  authority;
- make the model request a denied tool after malicious recall and assert the
  policy still denies with zero tool effects;
- test the application's own context assembler separately; a Core role change
  does not prove general prompt-injection prevention.

Reference tests:

- Go: `pkg/agent/memory_recall_test.go` in the Core repository.
- Python/TypeScript: add the equivalent two-run fixture in the consumer test
  suite; the public service-auth examples show loopback identity tests.

## Side-Effecting Applications

Add these checks when a tool can write, send, delete, or pay:

- final arguments are reauthorized after middleware or approval edits;
- an unknown outcome is queried before retry;
- an idempotency or operation key is bound to the effect;
- a completed run and a verified effect are recorded separately;
- cancellation is recorded as requested, confirmed, rejected, or unknown;
- corrupted or partial checkpoint state fails closed.

Retry checks should include the unsafe case, not only the recovery case:

- with `Attempts > 1` and no `ShouldRetry`, a non-idempotent tool is invoked
  again after a transport error; record that duplicate effect as a known hazard;
- with `ShouldRetry` returning false for unknown outcomes, assert one invocation;
- query authoritative status or reconcile the effect ledger before retrying;
- test that a status-query failure does not become an automatic retry.

See [Long-running operations](long-running-operations.md) and the
[retry safety recipe](../guides/recipes.md#retry-safety-and-unknown-outcomes).

## High-Risk or Multi-Tenant Applications

Add these checks when the deployment is privileged, multi-tenant, or
safety-relevant:

- a missing, expired, or tenant-mismatched principal is denied;
- a policy or identity service failure does not permit execution;
- revocation applies to queued work;
- tenant-scoped checkpoints and events cannot be read across tenants;
- shell, file, and network effects are blocked outside the declared boundary;
- an operator can stop and recover without repeating an effect blindly.

See [Application integration checklist](application-integration-checklist.md)
and [Identity and policy](identity-policy.md).

## Test Boundaries

- A fake model proves integration behavior, not model quality.
- A loopback server proves transport mapping, not a deployed service.
- A passing deny test proves that one denial had no effect, not that every path
  is secure.
- A checkpoint is not a transaction and does not prove an external effect.
- Test the exact package version and application commit you deploy.

## Keep the Evidence

Record the package version, application revision, model endpoint class, policy
owner, tenant scope, commands, expected result, observed result, and whether the
test was run in source mode or against a published package.
