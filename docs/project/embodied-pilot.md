# Embodied Pilot Plan

**Status:** proposed pilot plan, updated 2026-11-08. No named consumer, middleware,
simulation task, execution authority, observation source, verifier, or safety
owner is selected. This page is an acceptance plan, not a schedule, staffing
plan, or implementation claim. Detailed execution plans remain in internal
planning storage.

This plan turns the [Embodied Integration Profile](../reference/embodied-integration.md)
requirements E1-E8 into bounded, recordable evidence. It does not create a new
Core API, wire contract, runtime, or profile switch.

## Purpose

A pilot exists to answer one question with evidence: can a named consumer use
the existing Core seams, plus its own middleware and execution authority, to
submit embodied actions and report their outcomes without confusing acceptance,
completion, and verified effect?

Passing a simulation is not the goal. The goal is a reproducible record of which
requirements were enforced, by which component, under which faults, and which
requirements remain unsupported.

## Scope

One pilot consists of:

- one named consumer and a responsible maintainer;
- one middleware that translates Core tool calls into the consumer's action
  protocol;
- one bounded simulation task with a defined success condition and safe stop;
- one execution authority that owns authoritative remote operation state;
- one observation source and one independent verifier;
- an optional workflow/coordination service where durable recovery is required;
- a deployment safety owner for stops, interlocks, and escalation.

Start with deterministic fixtures, then end-to-end simulation. Hardware trials
are optional, separately approved, and never required to make simulation evidence
look stronger than it is.

## Non-goals

- No new Core API, event name, wire enum, profile constructor, or release line.
- No robotics platform, motion planner, hardware driver, certified safety
  controller, real-time runtime, or distributed transaction.
- No parallel ROS 2, Dora, or Zenoh adapters before a consumer demonstrates the
  need.
- No exactly-once claim, no hardware or production certification, and no
  emergency-stop implementation.
- Simulation is not hardware evidence; a tool reply is not an effect.

## Proposed Delivery

AKROVELA site execution and DIDACTOVELA capture/learning are optional candidate
boundaries, not prerequisites for every pilot. Both are unreleased `0.1.0`
operational bootstraps with no domain integration. A future node path needs its
own published operation/receipt contracts and failure tests; a learning handoff
needs explicit data admission and candidate/evaluation boundaries. Do not count
their initialization as P1/P2 evidence or silently migrate an existing consumer.

Deliver a named consumer example, one experimental middleware adapter, a
consumer-local operation/observation protocol, deterministic and simulation tests,
and scoped evidence. Reuse the governed unified assembly design, adding embodied
requirements rather than a separate security stack. No assembly implementation or
new Core constructor is delivered by this plan.

The protocol must cover submit, query, cancel request/confirmation, observations
and verification; bind operations to payloads, resources and execution epochs.
Specify deduplication retention and authoritative recovery. This is new
consumer-level protocol mapping work, not a shared `spec/` change. Reuse existing
versioned public execution and experiment contracts rather than defining a second
Mission or evidence model; gaps stay blocked until the owning contract is
published and reviewed. Keep middleware details
in the adapter; promote reusable integration contracts only after consumer
evidence, and Core APIs only for proven local execution gaps.

Record configuration validation separately from behavioral acceptance. A selected
level or bound dependency is not a capability guarantee. Missing mandatory
controls reject assembly; runtime authority, approval, freshness and resource
checks remain enforced at their actual boundaries.

## Roles and separated authority

| Role | Responsibility |
| --- | --- |
| Consumer | Owns the task, action protocol, resource scope, and evidence records |
| Maintainer | Keeps the pilot reproducible and reviews scope and claims |
| Core | Local Run, configured policy/HITL, tool invocation, events, cancellation, checkpoint contracts |
| Middleware | Translates commands and observations, correlates IDs, preserves unknown outcomes, enforces input and resource limits |
| Execution authority | Accepts or rejects commands, owns authoritative operation state, deduplicates, confirms cancellation |
| Observation source | Supplies timestamped observations with a declared clock domain |
| Verifier | Independently checks freshness, ordering, and the declared physical effect |
| Workflow/coordination service (optional) | Durable recovery, task coordination, leases, fencing |
| Safety owner | Owns controlled stop, interlocks, escalation, and approved safe state |

Keep local Run, coordination Task, durable Process, and robot Mission identifiers
and authority separate. These are conceptual mappings, not Core fields. A Run
completion must never be reported as a Mission completion.

## Entry criteria

The pilot stays **planned** until all of the following are recorded:

1. A named consumer and maintainer accept the obligations in the
   [Governed Execution Profile](../reference/governed-execution.md).
2. One middleware and one bounded simulation task are named.
3. The execution authority, observation source, verifier rule, and safety owner
   are named.
4. Freshness thresholds, clock domains, timeouts, ownership rules, cancellation
   protocol, and escalation behavior are documented.
5. Credential, tenant, secret, and evidence-retention handling is defined.
6. Exact Core, middleware, simulator, authority, and runtime versions are pinned.
7. Every governed G1-G8 and embodied E1-E8 requirement has an applicability rule,
   named enforcing component and planned allowed, negative and fault tests.
8. No Core API or wire change is requested before evidence exists.
9. Record public experiment/execution contract and SDK revisions, explicit
   experiment-attempt/Run/Mission bindings and supported capability mappings.
   Missing published surfaces or required capabilities block the affected gate.
10. Identify world-state and independent-assurance owners separately from raw
    experiment evidence and Mission execution; declare simulation namespaces,
    claim modes and local safety behavior under control-plane loss.

If any item is missing, the pilot remains a design discussion, not an
experimental implementation.

## Phases and gates

| Phase | Work | Evidence | Exit gate |
| --- | --- | --- | --- |
| P0. Baseline | Select consumer, middleware, simulation, authority, observation source, verifier, and safety owner; pin versions; map G1-G8 and E1-E8 to enforcing components and define the consumer protocol | Scope, protocol, responsibility map, threat/data notes and verifier independence | All entry criteria recorded |
| P1. Deterministic fixtures | Validate unified assembly; run governed and embodied allowed, negative and fault paths with fake dependencies | Configuration results, test names, assertions, run record | Applicable G1-G8 and E1-E8 deterministic gates pass, including a successful verified action; no live service required |
| P2. Simulation | Connect middleware, simulator, execution authority, observation source, and verifier on loopback; run happy path and required faults through the governed entry and actual effect boundary | Command and authority responses, observations, verifier receipts, cancellation confirmations, duplicate and stale-owner rejections | Applicable G1-G8 and E1-E8 simulation gates pass; no false completion; unknown outcomes stay unknown |
| P3. Optional hardware trial | Only with safety-owner approval and a defined safe stop; repeat selected tests | Hardware observations and limitations | Hardware evidence is scoped separately; not required for pilot acceptance |
| P4. Review | Review claims, gaps, residual risks, and promotion options | Published evidence summary and decision record | Decision recorded: keep experimental, stop, or request a reviewed contract change |

## E1-E8 test matrix

| ID | Deterministic fixture | Simulation | Evidence |
| --- | --- | --- | --- |
| E1 | Missing identity, mismatched target/scope, and approval edits block submission | Same checks survive real adapter and authority boundaries | Final action, parameters, authorization decision, and approval binding |
| E2 | Accepted command and successful tool reply do not mark the effect complete | Verifier confirms or rejects the declared effect after completion | Accepted, completed, and effect-verified outcomes recorded separately |
| E3 | Reject stale, replayed, wrong-resource/source/epoch and out-of-order observations, including expiry during approval | Recheck binding, sequence and freshness at final release with declared clock uncertainty | Source/resource/epoch, timestamp, sequence and freshness decision |
| E4 | Local Run cancellation and accepted cancel requests do not prove remote stop | Separate stop confirmed, cancel rejected and cancel outcome unknown; resolve completion races using authority state | Request, acceptance, stop confirmation or rejection/unknown, plus separate effect outcome |
| E5 | Lost response and duplicate submission resolve through the authoritative operation key | Query before retry; require authoritative no-effect or valid target deduplication; reject payload mismatch | Operation key, payload binding, retention window, query and observed effect count |
| E6 | Required policy, observation, authority, or safety dependency failure blocks new dependent actions | Same failure triggers the consumer-defined escalation path | Failing dependency, blocked action, and escalation record |
| E7 | Stale worker or lease cannot issue a new effect; checkpoint restore does not recreate authority | Fencing token is checked by the actual effect boundary | Stale-owner rejection and current-owner proof |
| E8 | Evidence record captures correlation without secrets | Evidence failure is separate from effect state; repair is append-only and never re-executes the effect | Command, responses, observations, cancellation, verifier result, redaction and repair provenance |

The governed [G1-G8 checklist](../reference/governed-execution.md#acceptance-checklist)
is also mandatory; E1-E8 alone cannot pass the pilot. Include alternate-entry and
post-validation mutation tests, identity/delegation/tenant checks, concurrent
single-use approval and crash windows, context restore/trust and pre/post-effect
evidence failures. Preserve per-requirement configuration results and behavioral
artifacts separately; documentation structure tests are not behavioral evidence.

At least one allowed end-to-end path must authorize, accept, complete, independently
verify the declared simulated effect and retain evidence. For each test specify
initial state, fault point, bounded wait, expected/observed effect count and final
authority/verifier assertions. A deny-all implementation cannot pass.

Map EC-13 to this matrix in the
[Execution Correctness Evidence Index](execution-correctness-evidence.md).
Deterministic fixtures are EC-D evidence; simulation is EC-I; hardware and
production observations are EC-O and remain separately scoped.

## Required fault coverage

At minimum, the pilot must inject:

- missing, stale, out-of-order, and clock-skewed observations;
- fresh wrong-robot observations, old-operation replay, approval-delay expiry and
  sequence/epoch resets after restart;
- middleware or authority disconnect before and after command acceptance;
- lost response after a durable or potentially durable effect;
- duplicate submission with the same and with a mismatched payload;
- delayed original submission, stale `not found`, expired deduplication keys and
  concurrent retries;
- cancellation that is requested, accepted, rejected, and never confirmed;
- confirmed remote stop and races between cancellation and completion;
- concurrent single-use approval consumption and crashes before invocation or
  after target acceptance but before local outcome recording;
- stale worker, stale lease, and restore-from-checkpoint ownership;
- required policy, observation, authority, and safety-service failure;
- verifier unavailability and evidence-storage failure.

For each fault, record whether the effect is confirmed, confirmed-absent, or
unknown, and whether new dependent actions were blocked.

The verifier must use evidence beyond the execution service's success flag.
Declare independence of process, observation source and trust domain, and shared
failure modes. A separate process reading the same success flag is insufficient.

## Evidence record

Keep experiment/run/attempt identity, scenario/control/SUT digests, seed, clock,
observer health, artifact integrity and cleanup evidence with each attempt.
Reference the experiment platform's raw evidence and Mission authority's effect
record without rewriting either into a caller-issued assurance verdict. Preserve
declared absence, calibration/fidelity limits and synthetic/replayed provenance;
missing required evidence is not a pass. No simulation fact may enter a real
operational view by implicit promotion. Raw evidence and final independent
assurance are separate artifacts, not a Core event or new shared wire envelope.

Test cross-attempt/tenant/epoch misbinding, replay-driven Mission resubmission,
missing public capabilities and observer/cleanup failures. Cleanup failure must
remain visible independently of effect outcome; no complete pass while required
isolation or cleanup evidence is missing. After experiment teardown, unresolved
remote work still needs authoritative cancellation/status reconciliation.

Each run records the fields required by the
[test evidence standard](../contributing/test-evidence.md): date, commit,
package and artifact versions, middleware and simulator versions, environment,
configuration, procedure, data, result, findings, and limitations. Keep raw
records in the owning product or internal storage; publish only scoped summaries
that name the exact revision.

Do not record credentials, tenant data, or personal data. A redaction check is
part of the evidence, not an afterthought.

## Acceptance and stop conditions

Pilot acceptance requires all of the following:

- every E1-E8 requirement passes deterministic and simulation gates;
- every applicable G1-G8 requirement passes both gates, and the allowed end-to-end
  path succeeds; skipped, blocked, failed or not-run mandatory checks prevent
  acceptance; exclusions narrow an experimental claim, not full acceptance;
- acceptance, completion, and effect verification remain distinct in every
  scenario;
- no unconfirmed cancellation is reported as a stop;
- no stale observation authorizes a dependent action;
- no unknown outcome is blindly retried;
- a required safety-dependency failure prevents new dependent actions;
- evidence is retained and correlated without secrets;
- limitations and unsupported behavior are published with the result.

Stop or fail the pilot immediately if:

- a local Run completion is presented as a Mission completion;
- an accepted command or tool reply is presented as a verified effect;
- a dependency failure becomes a false confirmed-safe state;
- the middleware or authority bypasses a required authorization or approval;
- evidence is fabricated, original timestamps are falsified, failed records are
  overwritten, or results are inferred from a different revision.

Legitimate repair appends the original gap, repair time, authoritative source,
operation correlation and responsible actor. Preserve the failed attempt; never
present repaired evidence as contemporaneous evidence or re-execute blindly.

## Promotion

Simulation success does not promote the profile. After P4, the maintainers may:

1. keep the result experimental for the named consumer;
2. stop the pilot and document why;
3. request a shared API or wire change, which requires a named consumer,
   negative tests, compatibility and language review, normative `spec/` updates,
   parity, conformance vectors, and consumer verification.

No profile label removes those requirements.

## Risks

| Risk | Mitigation |
| --- | --- |
| Simulation hides timing and physical uncertainty | Declare clock assumptions, inject skew and delay, and keep hardware evidence separate |
| Middleware accidentally becomes the authority | Name the authority owner and test its rejection and confirmation paths |
| Local cancellation is mistaken for remote stop | Record cancellation as requested, confirmed, rejected, or unknown |
| Duplicate-safe path is only application-level | Bind a stable operation key at the actual effect boundary and test payload mismatch |
| Stale ownership issues effects after recovery | Fence the effect boundary and test stale worker/lease rejection |
| Evidence pressure encourages fabricated history | Publish unknown and failed results; distinguish append-only repair from falsified original evidence |

## Open decisions

- Named consumer, maintainer, middleware, simulator, and bounded task.
- Execution authority and its status-query and deduplication behavior.
- Observation source, clock domain, freshness threshold, and verifier rule.
- Cancellation protocol and escalation path.
- Optional workflow/coordination service and fencing mechanism.
- Hardware scope and safety-owner approval.
- Evidence retention, redaction, and publication boundary.

## Related documents

- [Embodied Integration Profile](../reference/embodied-integration.md)
- [Governed Execution Profile](../reference/governed-execution.md)
- [Embedding and Execution Profiles](../reference/execution-profiles.md)
- [Execution Correctness](../project/execution-correctness.md) and its
  [evidence index](execution-correctness-evidence.md)
- [Long-running operation recipe](../guides/long-running-operations.md)
- [Test and Evidence Taxonomy](test-taxonomy.md)
- [Public Roadmap](roadmap.md)
