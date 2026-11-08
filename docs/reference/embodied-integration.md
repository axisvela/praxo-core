# Embodied Integration Profile

**Status: proposed design, updated 2026-11-08; AKROVELA is the selected pilot
consumer; consumer pilot not started.** No embodied runtime, middleware adapter,
new Core API or safety guarantee is introduced. Like PRAXOVELA, AKROVELA embeds
PRAXO-CORE as a component of its own product; Core remains product-neutral. This
page specializes the [execution levels](execution-profiles.md) and
[Governed Execution Profile](governed-execution.md), not the normative wire spec.

## Prerequisites

A pilot needs one named consumer, one middleware, one bounded simulation task,
an execution authority, an observation source and a verification rule. AKROVELA
is the selected consumer; its product-owned adapter, simulator mapping, execution
authority details, observation source and verifier remain unimplemented or open.
Do not build parallel ROS 2, Dora and Zenoh adapters without consumer evidence.
AxisVela products remain optional for independent consumers.

The consumer must identify the components enforcing the governed requirements.
An embodied integration cannot skip authorization or weaken failure handling by
selecting an "experimental" label. Development fixtures are not safety controls.

## Delivery and Contract Scope

AKROVELA is the selected pilot consumer and owns the product-side PRAXO-CORE
embedding adapter. Like PRAXOVELA, AKROVELA embeds PRAXO-CORE as a component of
its own product; the products retain different positioning and state. Core stays
a product-neutral MIT kernel and does not acquire AKROVELA operation, product,
Mission or safety state. AKROVELA and DIDACTOVELA remain unreleased `0.1.0`
products; the adapter and pilot evidence are not implemented. Selection does not
replace retained execution paths or close any governed/embodied gate.
KINETOVELA Mission and PEIRAVELA experiment identities remain distinct from node
attempts and learning lineage.

The proposed pilot delivers a consumer example, an experimental adapter for one
middleware, a consumer-local integration protocol, deterministic tests, simulation
and scoped evidence. It reuses the proposed governed assembly entry and adds
domain requirements, not a second governance stack. No reusable assembly package
or embodied adapter implementation is claimed by this design.

The consumer must specify submission, authoritative status queries, cancel request
and confirmation, observations and effect verification. This is a new integration
protocol even though no Core API is added. Define operation/payload binding,
resource scope, epochs, idempotency retention and recovery in that protocol; its
shapes are not shared Core fields or wire contracts.

Keep middleware-specific details in the adapter. Consider a separate integration
contract only after consumers demonstrate reusable remote-operation semantics;
consider `pkg/...` only for proven local execution gaps. Do not predefine Robot,
Mission or a generic async-action API. Shared promotion still requires ordinary
spec, compatibility, parity and conformance review.

## Responsibility Boundary

Experiment control, Mission execution, world-state authority and independent
assurance are different roles. A simulation controller owns experiment attempts
and raw evidence, not production Missions or assurance verdicts. A Mission
authority owns assignment and physical-effect lifecycle, not operational world
truth or certified local safety. The verifier supplies an independent scoped
result; it does not inherit authority from an executor's completion event.

Prefer existing versioned public product contracts to a competing consumer
protocol. Document missing public surfaces and capability gaps before adapter
implementation; a schema found only in implementation/private storage is not a
published integration dependency. Neither product internals nor AGPL-only runtime
code may be imported into this MIT framework. Public SDKs still require ordinary
dependency/license review. See the [ecosystem integration boundaries](../integrations/ecosystem.md).

| Component | Responsibility |
| --- | --- |
| Core | Local Run, configured policy/HITL, tool invocation, events, cancellation and checkpoint contracts |
| Consumer adapter | Translate operations and observations, correlate IDs, enforce input/resource scope, preserve uncertain outcomes |
| Execution authority | Accept/reject commands, own authoritative remote operation state, deduplication and cancellation confirmation |
| Observation/verifier | Supply timestamped observations, evaluate freshness and verify the declared effect independently of a success reply |
| Workflow/coordination service, if used | Durable recovery, task coordination, leases and fencing |
| Deployment safety system | Emergency stops, interlocks, real-time control, hardware limits and approved safe-state behavior |

Keep local Run, coordination Task, durable Process and robot Mission identifiers
and authority separate. Their names are conceptual mappings, not mandatory Core
fields. A Core run completion must not be promoted into a Mission completion.

Experiment run/attempt IDs are also distinct from Core Run and Mission IDs.
Use explicit scoped, versioned bindings; correlation and event naming alone do
not authorize state transitions. Preserve simulation provenance and claim modes:
simulated or replayed observations do not become real operational facts. Unknown
or conflicted required world state blocks dependent actions. Local safety must
remain independently operable when cloud, model or control-plane connectivity
fails; a SafetyEnvelope reference is not proof of enforced safety.

## Proposed Acceptance

All governed obligations apply. The following add domain-specific requirements;
these labels are documentation references, not wire codes or a new state enum.

| ID | Requirement | Negative or fault acceptance |
| --- | --- | --- |
| E1 | Authorize the final target, action and parameters | Missing identity, mismatched target/scope or approval edits prevent submission |
| E2 | Separate accepted, completed and effect-verified outcomes | An accepted command or successful tool reply alone never proves the physical effect |
| E3 | Bind observations and bound freshness | Validate trusted source, target/resource, operation or execution epoch and sequence; missing/stale/replayed/mismatched observations block dependent actions; recheck at final release after approval or queue delay |
| E4 | Confirm remote cancellation | Cancelling a local Run does not report remote stopping; absent confirmation remains unknown/pending |
| E5 | Resolve duplicate and uncertain submissions | Stable operation key binds payload; response loss/reconnect consults authoritative state before retry |
| E6 | Fail closed on required safety dependencies | Loss of required policy, observation or safety service prevents new dependent actions and invokes consumer-defined escalation |
| E7 | Fence recovery and concurrent ownership | A stale worker/lease cannot issue a new effect; checkpoint restore does not recreate execution authority |
| E8 | Retain correlated evidence | Capture command, authority response, observations, cancellation and verifier result without secrets; report evidence failure separately from effect state |

The consumer defines the freshness threshold, clock domain, timeouts, ownership
and cancellation protocol. This design does not invent universal safe defaults.
For an action already executing, "fail closed" does not mean Core can halt the
machine: the deployment safety authority owns controlled stop/escalation and its
confirmation. Never turn dependency loss into a falsely confirmed safe state.

Declare clock uncertainty and observation validity at final action release, not
only at planning. Test fresh observations from the wrong robot, old-operation
replay, expiry while awaiting approval and sequence resets after restart. The
verifier must use an observation path beyond the execution service's success
flag; record its process, data-source and trust-domain independence and shared
failure modes. A separate process alone does not establish independent truth.

Keep authority validity time, bounded observation time, simulator epoch/ticks and
local monotonic time distinct. Do not subtract timestamps from unrelated clocks.
With a declared combined clock-error bound `U`, require worst-case age
`release_time - observed_at + U <= max_age`, reject future timestamps beyond `U`,
and fail the dependent gate if the bound is unknown. Repeat reads do not refresh
observation time; source restart needs trusted epoch rebinding, not acceptance of
a larger integer. Simulator pause/rewind needs explicit invalidation rules.

Separate pre-action resource/environment evidence from post-attempt effect
observations; do not invent an attempt identity before the authority assigns it.
A simulator must produce observable state independently of a requested goal or
executor success flag. Synthetic fixtures test validation rules, not achieved
effects. Local scoped verification is not final independent assurance or another
owner's Mission effect admission. A product embedding adapter is not itself a
robot middleware, simulator or second Agent loop.

Keep cancellation request accepted, stop confirmed, cancellation rejected and
cancel outcome unknown separate. Rejection does not establish operation outcome;
a confirmed stop does not erase earlier effects. Resolve cancellation/completion
races through authoritative state without overwriting completed results.

## Evidence and Promotion

Before claiming an experimental implementation, record the named consumer and
middleware, exact Core/adapter/runtime versions, simulation environment and task,
enforcing components, each E1-E8 test/result and unsupported behavior. Test stale
observations, disconnects, lost responses, duplicate submissions, unconfirmed
cancellation, stale ownership and required safety-service failures.

Full pilot acceptance requires the governed G1-G8 checklist as well as E1-E8,
with allowed, negative and fault paths. Configuration validation and behavioral
acceptance are separate results. Missing mandatory evidence leaves acceptance
unsatisfied; partial experiments must narrow their claims.

The [embodied pilot plan](../project/embodied-pilot.md) turns E1-E8 into
deterministic, simulation, and optional hardware gates with required evidence and
stop conditions. AKROVELA is the selected consumer, but no adapter, simulation
mapping or run is recorded; it is not an implementation claim.

The [long-running operation recipe](../guides/long-running-operations.md) supplies
software-fixture examples of response loss, status recovery, cancellation and
fencing. It does not supply observations, middleware, production leases or an
embodied consumer; its passing tests do not satisfy this profile.

Separate deterministic fixtures, end-to-end simulation, hardware trials and
production observations under the [test taxonomy](../project/test-taxonomy.md).
Simulation is not hardware or production evidence. Publish limitations and
residual risks with each scoped result; no complete profile pass is claimed here.

## Non-goals

Core is not a robotics platform, motion planner, hardware driver, certified
safety controller, distributed workflow engine or real-time runtime. This profile
provides no emergency-stop implementation, external transaction atomicity or
generic exactly-once guarantee. Shared API/wire changes require the ordinary
compatibility/spec/parity process, not a profile-only exception.
