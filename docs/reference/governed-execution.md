# Governed Execution Profile

**Status:** proposed acceptance design, updated 2026-11-06. This is not an implemented
profile, new API, wire contract, or production-readiness claim. Current behavior
is described by the API, [event semantics](events.md), and release notes.

## Responsibility Boundary

This is the governed level of [Standard Embedding and execution profiles](execution-profiles.md).
It adds integration obligations, not a separate kernel or a new `agent.Profile`.

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

## Mandatory Entry Boundary

Current Go behavior intentionally permits `Policy == nil` and treats empty
`AllowedTools` as unrestricted. Keep that Standard Embedding behavior compatible.
A governed product such as PRAXOVELA must instead provide a mandatory assembly
entry that rejects missing controls before model calls, tool discovery/exposure
and tool execution. A caller must not silently fall back to ordinary `agent.New`
after validation fails. This entry is a product requirement, not a newly
implemented Core constructor.

The enforcing boundary must be owned by trusted assembly/tool services, not only
an optional middleware chain. Middleware must not remove required checks, replace
trusted identity or approval evidence, or cause the actual operation to differ
from the authorized one without reauthorization. Untrusted same-process code
needs an external isolation/enforcement boundary; a Go wrapper cannot contain it.

| Configuration or event | Standard Embedding today | Governed integration requirement |
| --- | --- | --- |
| Missing Policy | Authorization helper permits execution | Reject startup before model/tool access |
| Empty AllowedTools | All registered tools permitted by name scope | Reject missing scope; explicitly distinguish an allowed set, All and None |
| Required policy service unavailable | Hook errors terminate the affected path | Keep fail-closed; no permissive fallback |
| HITL edits final arguments | Core reauthorizes edited operations | Also bind approval evidence to final operation, context, validity and permitted use |
| Authorization revoked during an operation | No guarantee of immediate remote termination | Actual Effect PEP enforces commit-time constraints and the authority confirms stop/outcome |

All/None are conceptual scope choices, not new enum values or a changed wire
contract. Consumers must enforce them at tool exposure and invocation. In
particular, mapping None to today's empty AllowedTools would grant unrestricted
scope, not deny-all; explicit All still requires policy for each protected call.

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

### Governed Effect Boundary

The product and actual tool/business service own this boundary. Core supplies
authorization, approval and execution hooks, not a distributed transaction or
an enterprise enforcement service. AEGIVELA is an optional policy/approval
integration; independent consumers may supply another authority.

| Step | Owner and required behavior |
| --- | --- |
| 01 Intent | Consumer identifies the logical business operation and target resource, not just a model tool-call ID |
| 02 Resolve Context | Trusted verifier establishes caller/Agent identity, delegation, tenant and resource scope; model-supplied metadata is not authority |
| 03 Authorize | Policy/approval authority evaluates that operation and required approvals; errors deny |
| 04 Prepare | Effect PEP binds final tool/arguments, context, approval reference and validity, stable business idempotency key and execution constraints |
| 05 Invoke | Controlled tool/service boundary rechecks the binding and current constraints before performing the actual operation |
| 06 Confirm Effect | Execution/business authority distinguishes confirmed success, confirmed no-effect and unknown; a transport error or Run completion is insufficient |
| 07 Persist Evidence | Consumer stores the outcome, correlation and recovery information; evidence failure does not erase a committed effect |
| 08 Reconcile | Consumer queries authoritative state, deduplicates, compensates when allowed or requests human resolution; never blindly retries unknown effects |

The sequence describes responsibilities, not an atomic protocol. If durable
intent or approval evidence is required before execution, its persistence is a
gate in Authorize/Prepare, not something deferred to step 07. Failure of that
precondition prevents Invoke. A post-commit evidence failure requires repair or
reconciliation, not automatic rollback or a false no-effect result.

Approval evidence must bind the authenticated context, target, final parameters,
decision identity, validity interval and allowed use/replay semantics. Edits,
expiry, resource changes and queued execution require defined revalidation.
Same-argument Core reauthorization alone does not implement durable approval
consumption, revocation propagation or target-side commit enforcement. The actual
Effect PEP owns these checks; local Run cancellation is not proof of stopping an
operation already accepted by a remote service.

### Recovery Semantics

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

Use the proposed [Execution Correctness Suite](../project/execution-correctness.md)
to organize failure cases, keeping Core mechanics, actual enforcement and
operational outcomes separately evidenced.

Current evidence is partial: the four published-language consumer suites cover
application rejection of missing policy/scope, final-argument and approval-edit
reauthorization, and policy-service errors. The identity and long-running recipes
exercise selected application fixtures. They do not verify an unbypassable
product entry, production identity/delegation, durable approval validity or
revocation at the real Effect PEP. These remain consumer-level acceptance gates,
not checks declared complete by this document.

Use the [test evidence standard](../contributing/test-evidence.md). Link a claim
to exact Core and adapter revisions, executed scenarios, assertions, artifacts,
and remaining gaps. Separate historical local runs, current automated runs,
independent reproduction, and production observations.

Start with integration-level contracts and failure tests. Any promoted API or
wire change requires the compatibility policy, applicable `spec/` changes,
language parity updates, conformance vectors, and consumer verification.
No runtime, schema, or language support promise changes by publishing this design.
