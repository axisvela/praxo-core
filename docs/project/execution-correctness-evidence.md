# Execution Correctness Evidence Index

This page is the public index of execution-correctness checks across PRAXO-CORE and
its named consumers. It is not a claim that EC-01 through EC-14, a Profile, or a
production deployment has passed.

The EC contract is defined in [execution-correctness.md](execution-correctness.md).
Checks are deliberately distributed: Core owns local mechanics, while product
repositories own database, effect, sandbox, deployment and consumer evidence. Raw
logs and internal run records remain in the owning product repositories or private
planning storage.

## Snapshot

| Item | Result |
| --- | --- |
| EC-D local scope | `27/27` selected selectors, `scope-passed` (`scripts/execution_correctness.py --strict`) |
| EC-D report | `build/execution-correctness/20261107T035737Z-9efbaea7/` (local, reproducible; not committed) |
| Core revision | `9b7eac9` working tree used for this snapshot (dirty; includes the EC-14 scope addition) |
| Full EC-01..EC-14 acceptance | **Not run**; this index is a scope/evidence map, not acceptance |
| EC-I / EC-O | Partial local checks only; no deployed authority or independent AEP |

## Complete EC map

`Core` means `praxo-core`. Product rows are evidence owned by the named product and
are not part of the EC-D scope count.

| EC | Core / EC-D evidence | Product / EC-I evidence | What the evidence proves | Status / remaining |
| --- | --- | --- | --- | --- |
| EC-01 | `pkg/agent/parallel_outcome_test.go::TestParallelToolFailureStillReportsEveryOutcome`; EC-01 fix `65793fd` | PRAXOVELA tool/effect ledger tests | Every attempted tool outcome is reported after a batch error; first error is returned | Local notification only; external effect confirmation/unknown classification remains consumer-owned |
| EC-02 | No Core effect-authority claim | RHEOVELA: Postgres effect store, HTTP list/reconcile, 8-way reconcile, compensation effect, A/B/C boundary; PRAXOVELA: durable `effect_jobs` outbox + replay; demo C9 | Local Postgres effect state, duplicate suppression, reconcile and outbox replay | **Partial**; no real external provider post-commit/status query |
| EC-03 | `pkg/tool/retry_test.go` (`TestRetryMiddlewareHonorsShouldRetry`, `TestRetryMiddlewareZeroValueDoesNotRetry`, `TestRetryMiddlewareStopsOnContextCancellation`) | RHEOVELA/PRAXOVELA idempotency tests | Retry count/predicate/cancellation behavior; local idempotency | No non-idempotent target protection or provider-side idempotency proof |
| EC-04 | `pkg/agent/tool_authorization_test.go` final-argument/name reauthorization tests | PRAXOVELA governed startup, tool scope and CopilotKit gates | Final arguments/names are reauthorized; product entry rejects unsafe defaults | Persistent approval binding, expiry, consumption and replay remain product/EC-I |
| EC-05 | Core boundary audit; no default behavior change | PRAXOVELA P0 entry policy/boundary wiring | Core exposes the seam; product fail-closed entry is tested | Actual PEP commit/revocation and confirmed stop remain external |
| EC-06 | `pkg/agent` context-budget/compaction tests | PRAXOVELA adapter/config tests | Required context/budget failures are fail-closed | Consumer admission rules and source data remain external |
| EC-07 | Core boundary audit of system/Recall/Skills injection | PRAXOVELA context/trust tests | Core preserves trust boundaries in local paths | Source authentication and real permission enforcement remain external |
| EC-08 | `pkg/agent` cancellation test (`TestRunStopsStartingToolsAfterCancellation`) | PRAXOVELA cancellation/run tests | Local cancellation prevents later local tool starts | Remote task status/stop confirmation remains external |
| EC-09 | No Core checkpoint-as-transaction claim | RHEOVELA checkpoint/effect tests: 4/4 checkpoint paths; Postgres store | Checkpoint rebuild, stale checkpoint, intent preservation and effect-before-checkpoint retention | Business commit/checkpoint failure recovery remains consumer-owned |
| EC-10 | `pkg/agent` event-sink tests (pre-invocation fail, terminal failure not masked) | PRAXOVELA/RHEOVELA effect and audit tests | Callback/sink failures are surfaced without false success | Durable acknowledgement, pre-execution gate and post-commit evidence require product policy |
| EC-11 | Containment tests in `docs/project/verification-evidence.md` | None claiming real isolation | Path/process/WASM/local controls are contract/unit tested | **No real sandbox isolation**; external container/VM evidence required |
| EC-12 | No Core distributed-lock claim | EE Postgres nodes 6/6 (lease/fencing/concurrent acquire); RHEOVELA `ha_locks`/`stage_leases`/outbox 38/38; RHEOVELA 128-job + 1h soak | Real Postgres lease/fencing, outbox claim and long local concurrency | Multi-process deployed authority, tenant isolation and production load remain external |
| EC-13 | No Core physical-effect semantics | None | — | **Blocked**; no named embodied consumer, middleware or simulation |
| EC-14 | `pkg/agent/resume_test.go::TestRunResumesFromSessionMessages` (in the EC-D mechanics scope) | RHEOVELA Postgres store 38/38, HTTP effect, checkpoint 4/4; PRAXOVELA checkpoint/effect tests | Local resume ordering plus durable product store/checkpoint contracts | Durable logical identity, business dedup and authoritative recovery remain consumer-owned |
| EC-O | No Core claim | None | — | **Blocked**; no deployed environment, fault budget, permissions or independent AEP |

## Product evidence locations

| Product / repository | Evidence | Does not prove |
| --- | --- | --- |
| `praxo-core` | EC-D runner/inventory; Go agent/tool tests; verification evidence | Consumer effects, sandbox, deployment |
| RHEOVELA | Postgres store/effect/outbox/checkpoint/HTTP tests; C9 in `demo-repository/praxovela-e2e` | Production execution authority, external provider |
| PRAXOVELA | Effect ledger, A/B/C boundary, durable outbox, replay and runtime options | Real external provider status, full C separate-tx (C is an A alias) |
| PRAXOVELA-EE | Product entry audits/P0 tests | Deployed AEGIVELA/EIDOVELA or multi-tenant operations |
| enterprise-autonomy | Reference adapters and vertical-slice executable evidence | Production OMS/payment/carrier/inference systems |
| demo-repository | C9 run record, 60s/1h soak logs | Independent or production verification |

## Tag and release context

| Repository | Current tag / state | Tag needed? |
| --- | --- | --- |
| `praxo-core` | `v2.5.2`; EC-01 behavior fix, EC-D runner and this evidence page are Unreleased | **Yes, next Core release.** A minor release is safer because the EC-01 callback/stream ordering is observable; run the normal release gate first. |
| RHEOVELA | `v1.61.0`; later changes are tests/soak scripts only | No new tag required for those test-only changes. |
| PRAXOVELA | `v3.4.0`; **post-tag** runtime drain, dispatcher lifecycle and replay guard are code changes | **Yes, new PRAXOVELA release** (recommended minor) plus coordinated `PRAXOVELA-open` tag. |
| PRAXOVELA-open | `v3.4.0` | Must match the next PRAXOVELA core release tag. |
| PRAXOVELA-EE | Independent tags | No code change in this work; no tag required. |
| `enterprise-autonomy` | `v1.1.13`; public docs/evidence only | No new tag required unless the repository's docs-release policy says otherwise. |
| `demo-repository` | `v0.2.0`; evidence docs only | No new tag required. |

This table records the state at the evidence snapshot; it is not release
authorization. A source tag does not turn the local evidence into production
acceptance.
