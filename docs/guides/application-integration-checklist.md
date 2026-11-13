# Application Integration Checklist

Use this checklist before embedding PRAXO-CORE in an application. Start with the
risk tier that matches the work, not with the full repository test matrix.

## All Applications

- Pin a published package version and record the upgrade path.
- Keep provider credentials and tenant data outside the framework.
- Configure the model endpoint explicitly; do not rely on a hidden default in
  production.
- Define an explicit tool scope and deny by default where possible.
- Add one denial check that proves a denied call has no side effect.
- Set timeouts, cancellation, and graceful shutdown around the agent loop.
- Forward events to the application's observability pipeline.
- Keep tool output and model output untrusted.

## Read-Only Applications

Use this tier for search, retrieval, summarization, and workspace inspection.

- Allowlist only the read tools the application exposes.
- Use rooted file access and reject absolute paths and `..` escapes.
- Do not expose shell, package installation, or unrestricted network tools.
- Log tool names and outcomes without recording sensitive arguments.
- Test that a prompt-injected write request is denied.

Example: [Read-only Workspace Agent](workspace-agent-tutorial.md).

## Side-Effecting Applications

Use this tier when an agent can create, update, delete, send, or pay.

- Require application-owned authorization for every effect.
- Use idempotency keys or an operation key at the effect boundary.
- Treat a checkpoint as a recovery hint, not proof of a committed effect.
- Add approval for destructive or externally visible actions.
- Reauthorize final arguments after middleware or approval edits.
- Do not blindly retry an unknown outcome; query the authoritative state first.
- Record completion and effect verification separately.
- Keep an audit trail of intent, attempt, approval, result, and failure.

See [Identity and policy](identity-policy.md) and
[Long-running operations](long-running-operations.md).

## High-Risk or Multi-Tenant Applications

Use this tier for production systems with multiple tenants, privileged actions,
or safety-relevant effects.

- Authenticate the caller and pass a verified principal; ignore model-supplied
  roles.
- Scope storage, policy, checkpoints, and events by tenant.
- Isolate shell, file, and network execution at the OS or sandbox layer.
- Fail closed when a required identity, policy, or safety service is unavailable.
- Persist approvals and revocation in an application-owned store.
- Separate the execution authority from the agent runtime.
- Define an operational runbook for cancellation, recovery, and escalation.
- Record the deployment boundary and residual risks.

See [Security model](../security/index.md) and
[Containment](../security/containment.md).

## Core Responsibilities

Core provides the agent loop, model/tool contracts, policy hooks, events,
checkpoints, streaming, cancellation, and optional adapters. It does not provide:

- authentic identity or tenant issuance;
- a policy decision service;
- durable approvals or effect ledgers;
- a workflow engine or worker leases;
- network or process isolation;
- exactly-once execution;
- production model or provider guarantees.

## Anti-Patterns

- Adding policy without an allowlist.
- Treating an empty tool scope as deny-all in the current API.
- Using a checkpoint as a transaction.
- Retrying a timeout without checking authoritative state.
- Logging raw credentials, tenant data, or tool arguments.
- Assuming the Go example works unchanged in every language SDK.
- Calling a fixture or offline recipe production evidence.

## Copy the Right Tests

Use the [consumer test template](consumer-test-template.md) to copy only the
checks that match your risk tier into the application repository.

## Keep for Review

Record the package versions, model endpoint class, tool scope, policy owner,
approval model, checkpoint store, event destination, isolation boundary, and the
tests that were actually run. Name the exact revision and environment.
