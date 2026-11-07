# Contract and Evidence Status

**Status:** public planning reference, 2026-11-05. This page defines the status
words used in the roadmap and records the current state of major contract areas.
It is not a release schedule and does not expand any API or profile.

## Status Words

| Status | Meaning | Minimum evidence |
| --- | --- | --- |
| Implemented | The normative contract or public API exists in the Go reference and has automated tests | Source, API snapshot where applicable, and tests |
| Verified | Evidence is bound to a specific commit, artifact, and date | A recorded run or review for that exact revision |
| Proposed | Design or acceptance criteria only | A design document; no API, wire, or profile guarantee |
| Experimental | Available for a named consumer, but may change and is not in the stable promise | A consumer and tests that state the limits |
| Not run / Not started | No result or implementation evidence exists yet | None; do not report as passing |

`Verified` is scoped evidence. A later documentation-only commit does not extend
it. Integration tests do not prove adoption, and conformance tests do not prove
production security or operational readiness.

These words describe contract and evidence state. They do not replace the
language coverage labels `planned`, `partial`, `parity`, and `n/a` in
[`spec/parity.md`](https://github.com/axisvela/praxo-core/blob/main/spec/parity.md)
or the support levels in the [language matrix](../languages/matrix.md).

## Current Matrix

| Area | Status | Scope and limits |
| --- | --- | --- |
| Standard Embedding | Implemented; verified per cited API/package revision | Existing configurable embedding model; nil Policy and empty/unrestricted tool scope remain permitted; not a security certification |
| Execution Correctness Suite | Proposed inventory; EC-D mechanics scope runner implemented; full suite not run | EC-01 through EC-14; separate EC-D/EC-I/EC-O tracks; the implemented runner covers EC-01/03/04/06/08/10/14 local mechanics (EC-14 is resume ordering only) plus a separate EC-11 local containment scope, not a complete suite or Profile pass |
| Go reference API and shared wire artifacts (events, errors, JSON Schema subset, plugin) | Implemented; verified per release revision | Normative files and vectors in `spec/`; does not prove live providers or product deployments |
| Tool, Model, and Checkpoint wire descriptions | Implemented; descriptive at `SPEC_VERSION` 0.2.0 | Shared tool/model shapes and the checkpoint allowlist envelope are wire; Go checkpoint and parsed-tool-call projections are documented as `"wire": false` and are not frozen cross-language contracts |
| Go, Python, TypeScript, and Java consumer starters | Implemented; verified at their cited revisions | Published-package installation, build, and deterministic allow/deny checks; integration evidence, not adoption evidence |
| Python published-package upgrade | Implemented; verified by CI | Installs PyPI `0.2.4`, upgrades the unchanged consumer to `0.3.0`, and reruns governed compatibility checks; one version pair, not a general upgrade guarantee |
| TypeScript published-package upgrade | Implemented; verified by CI | Installs npm `0.1.5`, upgrades the unchanged consumer to `0.2.0`, and reruns starter/governed checks; one version pair, not a general upgrade guarantee |
| Java published-package upgrade | Implemented; verified by CI | Resolves Maven Central `0.3.0`, upgrades the unchanged consumer to `0.4.0`, and reruns starter/governed checks; one version pair, not a general upgrade guarantee |
| Go, Python, TypeScript, and Java governed negative acceptance | Implemented; verified at their cited revisions | Five application-level checks in each: missing policy/scope, final-argument and approval-edit reauthorization, policy-service failure; not a general profile |
| Go identity/policy recipe | Implemented; verified at its cited revision | Verified principal supplied by the application; missing, expired, tenant-mismatch, and model-role cases deny; not an identity provider or PDP |
| Go long-running operation recipe | Implemented; verified at its cited revision | L4 recipe evidence: file-backed (temp+sync+rename), loopback-HTTP, child-process restart, separate verifier process, and file-backed fencing fixture for idempotent submit, response loss, partial-write recovery, cancel request versus confirmation, Run cancellation, completion versus effect verification, verifier receipts, durable fencing, and static bearer/TLS rejection; only the Run-cancellation assertion touches a Core seam. No production key management, lease expiry/revocation, power-loss proof, identity provider, lock, or exactly-once |
| Go adapter conformance recipe | Implemented; verified at its cited revision | Uses `pkg/conformance` to validate fake model, streaming model, tool, and retriever contracts, including mismatch failures; no live provider or production evidence |
| Go retry safety recipe | Implemented; verified at its cited revision | Demonstrates `tool.Retry` predicates, cancellation, the non-idempotent duplicate-effect hazard, and a status-aware application wrapper; no Core effect ledger or exactly-once guarantee |
| Go event sink recipe | Implemented; verified at its cited revision | Demonstrates `MultiSink`, `FilterSink`, `PublisherSink`, pre-tool sink failure blocking, and terminal sink failure not masking the original error; no durable acknowledgement or production telemetry |
| Go context budget recipe | Implemented; verified at its cited revision | Demonstrates deterministic compaction, System-message preservation, fail-closed oversized prompts, summary compaction, and summary-model fallback; no general prompt-injection filter or source authenticity |
| Go checkpoint store recipe | Implemented; verified at its cited revision | Implements `checkpoint.Store` with temp-file + sync + rename, reopen recovery, partial-temp-file tolerance, tenant-scoped loads, and delete; teaching store, not a concurrent database or exactly-once proof |
| Go structured output recipe | Implemented; verified at its cited revision | Validates structured output and tool arguments with the `pkg/tool/jsonschema` subset, rejects invalid values before tool effects, and carries the schema in `ResponseFormat`; no provider structured-output guarantee or full JSON Schema support |
| Go VFS containment recipe | Implemented; verified at its cited revision | Demonstrates rooted `localfs`, traversal/NUL/root-delete rejection, symlink escape rejection when the host supports symlinks, read-only path grants, and deny-by-default empty grants; local host controls, not container/VM isolation |
| Go provider fallback recipe | Implemented; verified at its cited revision | Demonstrates primary model selection, predicate-gated fallback, both-fail behavior, cancellation without fallback, and nil-primary fallback; no provider SLA or failover service |
| Go plugin lifecycle recipe | Implemented; verified at its cited revision | Demonstrates ACTIVE-only Acquire, guarded transitions, in-flight drain with timeout/cancel distinction, revoke to UNLOADED, and terminal quarantine; not process/WASM isolation or manifest trust |
| Go multi-agent recipe | Implemented; verified at its cited revision | Demonstrates launch/completion/failure/cancel, mid-flight update gating, parent-session listing, terminal-only prune, and wait cancellation; local task coordination, not durable remote workers |
| Go streaming recipe | Implemented; verified at its cited revision | Demonstrates ordered `OnDelta` fragments, complete final response, stream error propagation, cancellation, and typed `OnStream` projections; no live provider or tool-delta aggregation guarantee |
| Workspace session contract example | Evaluation; verified offline with the fake provider | Runs the shared create/attach/upload/download/VFS/command/close/optional Pauser conformance checks; not part of `pkg/`, no live provider, no isolation evidence |
| Governed Execution Profile | Proposed; partial integration evidence | Mandatory product entry, explicit scope, approval binding and Governed Effect Boundary are acceptance requirements; no general Core profile or bypass-proof product entry is claimed |
| Coding-agent integration map | Implemented; versions checked by documentation tests | Package map, integration contract, and verification commands; not an install channel, automatic skill, or adoption evidence |
| Coding-agent discovery aid | Implemented; `llms.txt` exists and its links are tested | Machine-readable repository entry point; does not guarantee tool discovery, search ranking, installation, or adoption |
| Coding-agent skill template | Experimental; repository template only | Tool-neutral `SKILL.md`; installation and discovery are not verified, and no auto-install, MCP, or runtime-skill behavior is claimed |
| Registry page metadata | Source metadata updated; published pages not yet updated | PyPI, npm, Maven, and Go pages audited 2026-11-05; pages update only with a new release; other registries are release-checked |
| Coding-agent adoption experiments | Not run | No discovery, selection, first-pass, repair-cost, or retention data |
| Embodied Integration Profile | Proposed design; consumer pilot not started | Adds to governed requirements: remote action, fresh observations, cancel confirmation, effect verification and safety-dependency failure tests; requires a named consumer, middleware and simulation |
| Language conformance, feature coverage, and operational evidence | See `spec/parity.md`, the language matrix, and Behavior Lab | Separate dimensions; a released source tag does not supply operational evidence |

## Citing Evidence

When citing a status, name the revision, artifact, and result. Say which of these
the evidence covers:

1. contract conformance;
2. a published-package consumer check;
3. a real local service or provider integration;
4. a hardware, simulation, or production observation.

Do not use one level to imply another. See the
[test and evidence taxonomy](test-taxonomy.md) for L1-L6 and the mapping of the
consumer and long-running tests. In particular, the long-running suite is L4
application-recipe evidence; it is not a Core capability claim.

An explicitly required framework in a coding-agent experiment is
directed-integration evidence, not free-selection evidence. Correctly excluding
an unsuitable framework is a successful selection decision, not an adoption
failure.

For shared-wire change classification, see the normative rules in
[`spec/README.md`](https://github.com/axisvela/praxo-core/blob/main/spec/README.md)
and the [compatibility policy](compatibility-policy.md). Optional profiles do not
bypass wire, parity, or conformance review.
