# Governed Execution Design

**Status:** proposed acceptance design, 2026-10-29. This is not an implemented
profile, new API, wire contract, or production-readiness claim. Current behavior
is described by the API, [event semantics](events.md), and release notes.

## Responsibility Boundary

Core executes configured authorization, approval, tool, and lifecycle controls.
Integrators establish authentic identity, delegation, resource binding, durable
business effects, and recovery. A policy hook is not an isolation boundary
against malicious code running in the same process.

Keep the ordinary embeddable mode available. First validate a governed deployment
contract in reference integrations; do not add a Core constructor or enrich
`policy.Action` solely to match an enterprise identity model.

The source-tree [governed workspace example](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace)
demonstrates required local controls, single-use argument-bound approvals, and
invocation-time policy rechecks. It is not a general Core profile, authenticated
identity service, or durable approval/effect store, and is not a new release
guarantee.

## Governed Deployment

| Requirement | Rejection or verification condition |
| --- | --- |
| Mandatory authorization | Missing policy prevents model requests and tool execution |
| Explicit tool scope | Distinguish unrestricted scope, an allowed set, and deny-all; do not interpret today's empty `AllowedTools` as deny-all |
| Trusted security context | Reject missing, invalid, expired, or mismatched identity and tenant/resource bindings at the enforcing boundary |
| Final operation binding | Authorization and any approval evidence cover the final tool name and arguments; edits cannot reuse unrelated approval |
| Dependency failure | Required identity, policy, and pre-execution evidence failures cannot silently permit execution |
| Sensitive effects | Enforce credentials, resource limits, and approval requirements at the tool/service boundary, not through prompts alone |

Authorization of unchanged arguments does not establish perpetual authorization.
An integration must define expiry, revocation, queue-delay, and resource-version
semantics, including whether the service must revalidate at commit time.
Do not promise instantaneous revocation from a pre-execution check alone.

A security-context experiment should first reuse existing adapter contracts.
Record issuer/verifier responsibility, actor and agent binding, delegation
attenuation, tenant/resource scope, expiry, and decision correlation. Unverified
metadata is not authority. Promote a shared contract only with a named consumer,
negative tests, and compatibility review.

## Context Trust

Current Go recall and skill assembly uses System messages. The target is explicit
separation of deployment-owned instructions, approved skill instructions, and
untrusted retrieved or tool-provided data. A skill is not trusted merely because
it implements a skill interface.

Source and trust distinctions must survive assembly, summarization, compaction,
offload, and restore. Tests should inspect the constructed context and attempt
unauthorized effects using hostile memory, skills, and tool results. Fixed model
fixtures establish deterministic enforcement; real-model adversarial trials are
additional, versioned evidence rather than deterministic safety guarantees.

Changing a message role or adding delimiters is not an authorization mechanism.
Default-role changes require behavioral compatibility review and an explicit
migration or opt-in path, not a silent patch justified by an unchanged API file.

The source-tree governed workspace example includes an opt-in context admission
path with digest-bound approved skills, data-wrapped memory/tool/summary
material, lineage-preserving compaction, and configuration-rebuilt text restore.
It is an example contract, not a Core API or a general prompt-injection filter,
and does not authenticate source identity or provide durable lineage.

## Effects and Recovery

`tool.call` denotes intent, not proof of execution or commit. Stream projections,
`run.completed`, memory writes, and checkpoints do not form a transaction.
An execution error does not prove that an external effect did not occur.

The integration must distinguish intent, attempted execution, confirmed business
commit, rejected/no-effect, and unknown outcome. Evidence persistence is a
separate dimension: a committed effect may temporarily lack durable evidence.
These are design distinctions, not new Core event names or a required wire enum.

Use a stable logical-operation idempotency key scoped to the business operation
and bind it to request content. A newly generated run or model tool-call ID is
not automatically suitable. Define key retention, payload mismatch rejection,
concurrent retry handling, and the authoritative status-query mechanism.

| Fault | Required evidence |
| --- | --- |
| Policy or approval rejects | No business effect occurred |
| Crash before execution | Retry starts without creating duplicate effects |
| Commit succeeds but response is lost | Query or retry with the same operation key resolves the original result |
| Commit succeeds but evidence storage fails | Reconcile or repair evidence without blindly executing again |
| Checkpoint is older than the effect | Recovery consults authoritative business state before retry |
| Target has no deduplication or status query | Document the limitation and require manual resolution or a defined compensation path |

Do not claim generic exactly-once execution. Audit delivery and business commit
need an explicit consistency mechanism; an extra completion event cannot supply
one. Preserve the original failure while reporting evidence-delivery failures
through a defined diagnostic path; avoid recursive failure-event emission.

## Evidence and Promotion

Use the [test evidence standard](../contributing/test-evidence.md). Link a claim
to exact Core and adapter revisions, executed scenarios, assertions, artifacts,
and remaining gaps. Separate historical local runs, current automated runs,
independent reproduction, and production observations.

Start with integration-level contracts and failure tests. Any promoted API or
wire change requires the compatibility policy, applicable `spec/` changes,
language parity updates, conformance vectors, and consumer verification.
No runtime, schema, or language support promise changes by publishing this design.
