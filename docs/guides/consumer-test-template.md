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
[`examples/consumer-go/governed_test.go`](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-go/governed_test.go).

## Side-Effecting Applications

Add these checks when a tool can write, send, delete, or pay:

- final arguments are reauthorized after middleware or approval edits;
- an unknown outcome is queried before retry;
- an idempotency or operation key is bound to the effect;
- a completed run and a verified effect are recorded separately;
- cancellation is recorded as requested, confirmed, rejected, or unknown;
- corrupted or partial checkpoint state fails closed.

See [Long-running operations](long-running-operations.md).

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
