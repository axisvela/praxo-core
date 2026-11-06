# Execution Correctness Suite

**Status: proposed acceptance inventory with an implemented local EC-D scope
runner, 2026-11-06.** This page defines the Execution Correctness Suite (EC).
The runner covers only the declared local mechanics scope; the full EC inventory
is planned/not-run. Existing tests may be reused after assertion review; this
page does not recertify them.

## Purpose

Complement the [Behavior Lab](../languages/behavior-lab.md) with failure-boundary
tests for autonomous execution. Do not replicate twenty routine scenarios across
every language or expand APIs simply to increase coverage counts. Start with the
Go reference and named consumer integrations. Language expansion follows actual
consumer demand and the shared spec/parity process.

Use [Standard Embedding and execution profiles](../reference/execution-profiles.md)
to state the evaluated integration scope. The
[Governed Effect Boundary](../reference/governed-execution.md#governed-effect-boundary)
assigns intent, authorization, invocation, effect confirmation and reconciliation
to their enforcing owners; an EC test does not transfer those responsibilities.

## Verification Tracks

EC uses track names rather than redefining the existing L1-L6
[test taxonomy](test-taxonomy.md).

| EC track | Object and implementation location | Existing evidence categories |
| --- | --- | --- |
| EC-D Deterministic | Core-owned state machines, authorization, callbacks, cancellation, errors and result propagation in PRAXO-CORE | L1; L2 only for separately executed SDK conformance; application fakes remain L4 |
| EC-I Integration | Real databases, gateways, effect ledgers and sandbox runtimes in consumer/product integration tests | L4 for application recipes; classify actual service evidence by its tested scope, not merely by the track name |
| EC-O Operational | Process crashes, network partitions, concurrent load, multi-tenant deployment and real devices in product deployments and independent validation | L6 when actual operational evidence exists; simulated faults alone are not production evidence |

Passing EC-D does not pass EC-I; passing EC-I does not satisfy EC-O. A single
scenario can have independently recorded results in several tracks. SDK or
published-package execution may additionally provide L2/L3 evidence, but does not
upgrade the effect or deployment claim.

Independent validation can be supplied by TEKMOVELA or another qualified
validation system. No AxisVela product is a mandatory Core dependency.
PRAXOVELA effect-ledger and RHEOVELA workflow tests are possible product-owned
EC-I integrations, not implementations that must move into PRAXO-CORE.

## Scenario Inventory

Outcome, Unknown, Accepted and Physical Commit below are semantic descriptions,
not new Core types, event names, error codes or a shared wire state machine.

| ID | Failure scenario | Required acceptance | Ownership and tracks |
| --- | --- | --- | --- |
| EC-01 | One parallel tool fails after other calls commit | Account for every attempted call as confirmed or explicitly unknown; a batch error must not imply no effects | Core callback/result propagation EC-D; external outcome ledger and verification EC-I/O |
| EC-02 | Tool commits but its response is lost | Resolve the authoritative state before a retry could create an unconfirmed duplicate | Consumer/tool authority EC-I/O; deterministic protocol fixture is only a model |
| EC-03 | Tool retry targets a non-idempotent operation | Prevent unguarded automatic retry; require a proven no-effect outcome or target-enforced idempotency/status resolution | Core retry-policy mechanics EC-D; guarded retry configuration and Effect PEP EC-I/O |
| EC-04 | Parameters change after approval | Original approval cannot authorize changed final operation; bind final arguments and approval validity/use | Core final authorization EC-D; durable approval and Effect PEP EC-I/O |
| EC-05 | Authorization is revoked while a tool waits | Refuse at the final execution/commit boundary or confirm termination according to the target protocol; never promise instant stop from a local check | Core recheck seam EC-D; actual enforcement authority EC-I/O |
| EC-06 | Context compaction exceeds budget | Preserve mandatory instructions or fail explicitly; never silently discard them to meet the budget | Core context assembly/compaction EC-D; consumer admission policy EC-I |
| EC-07 | Untrusted memory contains forged instructions | Untrusted content gains no higher instruction authority or permission through assembly/restore | Core context handling EC-D; source authentication and integration policy EC-I/O |
| EC-08 | Agent is cancelled while external work continues | Do not claim that external effects stopped without authoritative confirmation | Core local cancellation EC-D; remote cancel/status protocol EC-I/O |
| EC-09 | Effect commits before checkpoint persistence | Recovery queries authoritative business state before repeating effects | Consumer effect/checkpoint integration EC-I/O; fixtures do not make checkpoints transactions |
| EC-10 | Event sink fails | Never report evidence as durably saved without the required acknowledgement; distinguish pre-effect gate failure from post-commit evidence repair | Core configured callback/error behavior EC-D; durable evidence acknowledgement/storage EC-I/O |
| EC-11 | Sandbox API matches but isolation is insufficient | No promotion to a verified isolation level from API conformance alone; state unsupported controls and actual platform limits | Core adapter contract EC-D; real containment validation EC-I/O |
| EC-12 | Agents concurrently modify the same resource | Resource versions, concurrency control or fencing reject stale/conflicting effects | Consumer resource authority EC-I/O; Core fake tests do not implement a distributed lock |
| EC-13 | Robot accepts a task but does not complete it | Accepted is not Physical Commit; completion and observed effect require separate evidence | Embodied consumer simulation EC-I; actual device/deployment EC-O |
| EC-14 | Interrupted work is recovered repeatedly | Preserve logical operation identity and prevent unintended duplicate effects; uncertain state requires reconciliation | Core restore/cancel seam EC-D; consumer durable operation authority EC-I/O |

## Existing Evidence Candidates

The [audited inventory](https://github.com/axisvela/praxo-core/blob/main/scripts/execution_correctness_inventory.json)
maps all fourteen IDs to local assertion candidates or explicit external/gap
dispositions. Its initial `core-mechanics-baseline` scope selects only local
parts of EC-01/03/04/06/08/10. EC-01 covers local outcome notification only;
external effect confirmation remains external. The inventory is not a runner or execution report;
all full-scenario acceptance fields remain not-run. Structure tests check that
mapped test functions exist, not that their execution satisfies an EC scenario.

These are reuse candidates, not a complete EC pass matrix. Review the exact
assertions, revision, environment and negative case before assigning an EC result.

| Candidate | Potential EC coverage | What remains outside it |
| --- | --- | --- |
| `pkg/agent/tool_authorization_test.go` | EC-04 local final-operation checks | Durable approval consumption/expiry and actual target enforcement |
| `pkg/agent/tool_cancel_test.go`, `completion_cancel_test.go` | EC-08 local cancellation | Remote stop confirmation |
| `pkg/agent/context/` and context integration tests | EC-06/07 local context rules | Authentic source lineage or general prompt-injection prevention |
| `examples/governed-workspace` | EC-04/05/07 application-level approval, invocation recheck and source wrapping | Opt-in L4 pattern; not Core default, product mandatory entry, real PEP, or source authenticator |
| `examples/recipes/long-running-go` | EC-02/08/09/12/14 application fixtures | Deployed execution service, production leases, partitions and power-loss proof |
| Sandbox/host tests and declared platform limits | EC-11 contract and selected containment checks | Whole-deployment isolation or certification |

The existing `tool.Retry` zero value uses one attempt. Configuring multiple
attempts does not automatically infer effect safety: a missing ShouldRetry
predicate does not supply target idempotency. EC-03 is an acceptance requirement,
not a claim that a non-idempotency guard has been implemented in Core.

Likewise `event.Sink.Emit` returning success is not by itself proof of durable
storage. EC-10 must name what the sink acknowledges and the integration policy
for failed required evidence. A post-effect error cannot establish no-effect.

## Recording and Acceptance

Use the [test evidence standard](../contributing/test-evidence.md). For each
scenario/track record the required scope, Profile/design revision, exact package
and dependency versions, tested SHA, fault point, initial state, logical operation
key, authoritative verification query, expected/observed effect count and evidence
acknowledgement, command/output, outcome and artifact references.

Keep passed, failed, skipped, blocked and not-run separate. Retain each attempt
and initial failure. Missing required tracks or fault assertions leave acceptance
unsatisfied; do not count absent integration/operational evidence as a pass.
Optional exclusions need a reason and must narrow the claim. Do not turn a
documentation inventory check into an execution result.

## EC-D Scope Runner

The local mechanics runner is implemented in
[`scripts/execution_correctness.py`](https://github.com/axisvela/praxo-core/blob/main/scripts/execution_correctness.py).
It reads the audited inventory and the `core-mechanics-baseline` scope, then runs
only the named parent tests with `go test -json -count=1` and `GOWORK=off`.

```bash
python scripts/execution_correctness.py --strict
```

Strict mode is the default; `--advisory` writes a report but returns success for
a scope failure. `--go` selects the toolchain, `--timeout` sets the Go timeout,
and `--output` changes the report root. A required parent or subtest must have an
exact terminal `pass`. Missing, skipped, failed, blocked, timed-out, conflicting,
or malformed results are not a pass. The runner records the inventory hash,
design revision, command, exit code, raw JSON events, stdout/stderr, and the
selected outcomes.

Each run is written under `build/execution-correctness/<run-id>/` with
`report.json`, `report.md`, raw events, and logs. `latest.json` is a convenience
pointer; previous run directories are not overwritten. The report status is
`scope-passed`, `scope-failed`, or `invalid`, never a claim that the whole EC
suite or a Profile passed. The initial scope covers only EC-01/03/04/06/08/10 local
mechanics; EC-01 is notification-only, and EC-02, EC-05, EC-07, EC-09, EC-11
through EC-14, EC-I, EC-O, and all Profile acceptance remain not-run or external.

## Roadmap Sequence

1. Map existing deterministic assertions to EC IDs and expose missing cases as
   gaps; do not duplicate tests or invent effect metadata to fill cells.
2. Implement a scoped EC-D runner/report with regression tests for error and
   unknown propagation, retry configuration, authorization and context boundaries.
   It must not imply that an external outcome was verified by Core.
3. Add named consumer EC-I evidence for databases, effect/approval enforcement,
   real isolation and recovery; reuse existing hooks before proposing APIs.
4. Run consumer-owned EC-O fault/load/deployment validation and an embodied
   simulation only after its prerequisites exist. Hardware and production
   observations remain separate from simulation.

Stages 1-4 above are proposed work, not completed milestones. Any shared security
or effect contract change still requires compatibility, normative spec, vectors,
parity and SDK impact review. This design adds no Profile API or default behavior.
