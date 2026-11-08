# Governed Execution Profile

**Status:** proposed acceptance design, updated 2026-11-08. This is not an implemented
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

## Unified Assembly Design

There is no general Governed switch today. Policy, scope, HITL and events are
configured separately, and consumers supply the external enforcement. The target
is one trusted assembly entry with structured configuration and dependency
validation, not a boolean that implies external guarantees. Validate this first
in a named consumer using existing seams; no new `pkg/...` API is proposed here.

The entry validates before model requests or tool exposure, then returns only a
controlled run entry. It must not hand untrusted callers mutable security options
or unguarded tool handles. Missing controls, unsupported mandatory capabilities
and conflicting configuration reject construction; no fallback to `agent.New`.
This protects trusted assembly against mistakes, not malicious same-process code.

The following is an illustrative consumer configuration, not a supported file
format, Core option, or shared wire schema:

```yaml
execution:
  level: governed
scope:
  mode: allowlist
  tools: [robot.submit, robot.status, robot.cancel]
security:
  identity: required
  policy: required
  approval: required-for-sensitive-actions
effects:
  recovery: authoritative-query
  retry: guarded
evidence:
  before-effect: required
  after-effect-failure: reconcile
```

Scope must explicitly distinguish `all`, `none` and `allowlist`; None must be
enforced at both exposure and invocation, not translated into empty AllowedTools.
Trusted code binds verifier, policy, approval, effect and evidence dependencies;
credentials and authority cannot come from model-controlled configuration. A
selected level chooses obligations; it does not create the missing services.

| Layer | Enforcement responsibility |
| --- | --- |
| Assembly | Required dependencies, explicit scope, compatible configuration, no permissive fallback |
| Core | Configured authorization, final-operation reauthorization, local lifecycle and cancellation |
| Tool / Effect PEP | Approval consumption, final binding, resource constraints and current authority |
| Execution authority | Deduplication, authoritative status, cancellation confirmation and fencing |
| Deployment | Isolation and, where applicable, controlled stop and safety systems |

Assembly validation is not behavioral acceptance. Record requirement ID,
enforcing component, configuration result, exact behavioral test/artifact and
remaining gaps separately. A configured client does not prove response-loss
recovery. Startup checks do not replace per-operation expiry, revocation and
resource-version checks. Configuration changes require revalidation before use;
queued work must still satisfy its execution-time constraints.

## Governed Deployment

| Requirement | Rejection or verification condition |
| --- | --- |
| Mandatory authorization | Missing policy prevents model requests and tool execution |
| Explicit tool scope | Distinguish unrestricted scope, an allowed set, and deny-all; do not interpret today's empty `AllowedTools` as deny-all |
| Trusted security context | Reject missing, invalid, expired, or mismatched identity and tenant/resource bindings at the enforcing boundary |
| Final operation binding | Authorization and any approval evidence cover the final tool name and arguments; edits cannot reuse unrelated approval |
| Dependency failure | Required identity, policy, and pre-execution evidence failures cannot silently permit execution |
| Sensitive effects | Enforce credentials, resource limits, and approval requirements at the tool/service boundary, not through prompts alone |

### Acceptance Checklist

G1-G8 are stable documentation references, not Core symbols or wire codes. A full
governed integration must evidence every requirement; conditional mechanisms such
as approvals need an explicit applicability rule. Skipped, blocked, failed or
not-run mandatory checks leave acceptance unsatisfied. Justified exclusions may
support a narrower experiment, not a full-profile claim.

| ID | Obligation and minimum acceptance |
| --- | --- |
| G1 | Trusted mandatory assembly rejects missing controls before model access, discovery/exposure or execution; test alternate entries, fallback and post-validation mutation |
| G2 | Explicit All/None/allowlist scope holds at exposure and invocation; None permits no tools and edits cannot expand scope |
| G3 | Trusted identity, actor/agent, attenuated delegation, tenant and resource binding; reject missing, expired, replayed or mismatched authority under the declared protocol |
| G4 | Final-operation and approval binding, validity, consumption and revocation; test edits, queue delay, concurrent single-use consumption and crash recovery |
| G5 | Required dependency and pre-effect evidence failures reject new dependent operations; enforce credentials, resource constraints and required isolation at the actual boundary |
| G6 | Context trust survives assembly, summary, compaction, offload and restore; hostile data cannot gain instruction authority or execution permission |
| G7 | Stable logical operation identity, guarded retries, authoritative recovery, resource concurrency/fencing and truthful cancellation; test lost responses, stale checkpoints and owners |
| G8 | Correlated, redacted evidence with defined acknowledgement; separate pre-effect gates, post-commit repair and effect outcome; retain failed attempts |

For every applicable G requirement include an allowed path as well as negative
and fault tests. An implementation rejecting all work cannot pass by exhibiting
only zero unauthorized effects. Each test defines initial state, injection point,
bounded wait, expected/observed effects and authoritative outcome assertions.

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

The consumer must identify the concurrency arbitration point binding approval
use to a logical operation. Two workers cannot spend a single-use approval on two
operations. Define recovery for a crash after reservation/consumption but before
invocation, and after target acceptance but before local recording. Retrying the
same operation must not accidentally consume a second approval or create a second
effect. Test those windows, concurrent consumption, revocation and resource-version
changes before final release. This requires a documented target-side protocol,
not a new Core distributed transaction.

Review the exact approval/digest coverage of effective resource constraints,
observation prerequisites and retry/retention policy, not only the nominal tool
arguments. A well-formed reference or digest is not an authenticated grant or
enforced limit. Keep tool calls bounded and responsive to Run cancellation;
later product reconciliation needs a separate authorized lifecycle, not hidden
background retries or an uncancellable call holding the Run open.

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

A status query alone does not authorize retry. A `not found` from a lagging
replica, expired idempotency record, or request still in flight is not a proven
no-effect result. Retry requires authoritative no-effect evidence under the
declared protocol, or target-enforced deduplication within a valid retention
window. Otherwise keep unknown and reconcile or escalate. Test delayed original
submission, stale queries, expired keys and concurrent retries.

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

Evidence repair is append-only: preserve the original failure and record the
repair time, authoritative source, operation correlation and responsible actor.
Never fabricate an original observation time or overwrite a failed attempt with
a later success. Repair is not blind re-execution.

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
