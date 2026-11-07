# Public Roadmap

Current core release: `2.6.0`. This is an **execution-kernel contract roadmap**:
it covers the contracts and verified behavior Core owns, and names evidence that
belongs to products or integrations. It is not a delivery schedule or a promise
that every Core implementation supports every feature.

## Next-stage Direction

**Planning update: 2026-11-05.** The next stage prioritizes correct adoption and
verified integration over implementation counts: a consumer or coding agent
should be able to identify a suitable task, install published packages, verify
governed behavior, and retain the dependency through upgrades.

Keep the positioning **governed, embeddable agent execution kernel**. Embodied
applications are an optional integration direction, not a redefinition of Core
as a robotics platform or a claim to provide a complete planner or safety system.
AxisVela products remain optional; independent consumers use the same contracts.

The following stages are acceptance gates, not dates, release assignments, or
implemented profiles. Existing security fixes and support commitments continue
throughout; the stages do not postpone maintenance or require every activity to
run sequentially.

| Stage | Deliverable | Acceptance gate |
| --- | --- | --- |
| 0. Establish the baseline | Map recommended package versions to consumer checks and evidence; distinguish implemented, proposed, experimental, and verified scope; establish adoption-task baselines | Historical compatibility, current recommended packages, and release candidates have separate evidence; contract/versioning ambiguities are resolved before affected contract changes |
| 1. Close the consumer path | Independent Go, Python, TypeScript, and Java starters using published packages, deterministic models, explicit tool scope, and allow/deny tests; task-oriented selection guidance | No source checkout, local replacement, unpublished dependency, API key, or external model service is required to run the starter; installation may require registry access; denial produces no tool effect |
| 2. Verify governed integration | Consumer-runnable acceptance tests, integration recipes, concise coding-agent instructions, optional installable skills, and accurate registry descriptions | Missing mandatory controls and required security-service failures reject execution; final operations and approval edits are checked; uncertain outcomes are not blindly retried |
| 3. Validate long-running operations | One consumer-backed integration for submission, status queries, feedback, cancellation, idempotency, and reconnect/recovery | Run cancellation is not reported as remote execution stopping; recovery consults the authoritative operation state before repeating effects |
| 4. Pilot embodied integration | One named consumer, one middleware, and one end-to-end simulation with an experimental embodied integration profile | Acceptance, completion, and effect verification remain distinct; observation freshness, disconnects, duplicate submissions, and safety-dependency failures are tested; simulation is not hardware or production evidence |

The initial four starter languages are an adoption pilot, not a downgrade of
Rust, C#, R, or other declared implementation support. Extend starters and
adapters when consumers and maintainers justify the work, not to increase counts.

The [independent Go consumer](../getting-started/consumer-go.md),
[Python consumer](../getting-started/consumer-python.md),
[TypeScript consumer](../getting-started/consumer-typescript.md), and
[Java consumer](../getting-started/consumer-java.md) implement the four pilot
current-package starter paths. Their published-package installation, build, and
deterministic allow/deny checks pass in CI, and [Start Here](../getting-started/index.md)
provides task-oriented selection guidance.

Stage 1's consumer-path acceptance is therefore met for the four pilot
languages. This is integration evidence, not adoption evidence: the adoption
experiments have not run, and stages 2-4 are unchanged. The pilot language set
does not reduce support commitments for Rust, C#, R, or other implementations.

Stage 0 is partially complete. The status vocabulary and shared-wire change
classification are documented in [Contract and Evidence Status](contract-status.md),
and the Tool, Model, and Checkpoint wire descriptions are implemented. The
adoption-task baseline and cross-product authority verification remain open.

Stage 2 has started with Go, Python, TypeScript, and Java consumer-runnable
governed negative tests covering missing policy/scope, final-argument
reauthorization, approval-edit reauthorization, and policy-service failure.
A concise [coding-agent integration contract](../getting-started/coding-agents.md),
a version-checked [package map](../getting-started/agent-integration.json), a
runnable [identity/policy recipe](../guides/identity-policy.md), and a
tool-neutral [skill template](https://github.com/axisvela/praxo-core/tree/main/agent-skills/praxo-integration)
are now available. Source registry metadata was improved and the four pilot
registry pages were audited; the published pages update only with new releases.
Stage 2 is not complete: skill installation/discovery is unverified, additional
integration recipes are open, and published registry-page verification requires
new releases.

Stage 3 has started with a Go consumer-runnable
[long-running operation recipe](../guides/long-running-operations.md) covering
idempotent submit, HTTP response loss, child-process restart recovery, cancel
request versus confirmation, Run cancellation, completion versus effect
verification, verifier receipts, partial-write recovery, fencing tokens, and a
separate verifier process and durable fencing. It uses file-backed loopback HTTP
fixtures with a static bearer token and test TLS, not a deployed identity-aware
service, production key management, database, or expiry/revocation-aware lease
store. This is L4 application-recipe evidence, not a Core capability claim; Core
cancellation and reauthorization are covered by `pkg/agent` tests and vectors.
Stage 3 is not complete: a deployed execution service, power-loss/fault
injection, and production leases/fencing remain open. See the
[test and evidence taxonomy](test-taxonomy.md).

### Consumer and Contract Baseline

The historical `tests/consumer` fixture pins Core `2.5.0`; the independent Go
starter tests recommended `2.6.0`. Both reject module replacements. A separate
`scripts/test_go_upgrade.py` check now installs the historical package, upgrades
the same consumer to the recommended package-map version, verifies unchanged
application source and runs the governed negative tests after upgrade. CI runs
it on Linux, Windows and macOS; results are scoped to each executed version pair
and platform, not inferred from the presence of a job.
A separate `scripts/test_python_upgrade.py` check installs Python `0.2.4`, runs
the unchanged consumer fixture and governed compatibility checks, upgrades to
`0.3.0`, and reruns the full starter/governed suite; CI runs it in the Python
consumer matrix. A TypeScript equivalent (`scripts/test_typescript_upgrade.py`)
covers npm `0.1.5` -> `0.2.0`, and a Java equivalent
(`scripts/test_java_upgrade.py`) covers Maven Central `0.3.0` -> `0.4.0`, with
the same unchanged-source checks. Historical compatibility, current-package
installation,
published-package upgrade, and release-candidate checks remain separate
evidence. These upgrade fixtures do not validate unpublished candidates or
establish adoption/retention.

Use the existing normative `spec/`, not a competing specification tree. The
Tool, Model, and Checkpoint wire descriptions now exist; entries marked
`"wire": false` document Go/source projections and are not frozen cross-language
contracts. Source, wire, and behavioral compatibility rules are distinguished:
the Go additive-field allowance does not automatically authorize a shared-wire
addition. Optional profiles cannot bypass shared wire, parity, or conformance
review.

Implement integration requirements through existing seams first. Promote a
public API only after a named consumer demonstrates a reusable gap, negative
tests cover it, and compatibility and language impact have been reviewed. The
[governed execution design](../reference/governed-execution.md) remains a proposed
acceptance design, not an implemented general profile.

### Adoption Evidence

Establish the baseline before changing discovery and integration materials.
Keep these evaluation tracks separate:

| Track | Question |
| --- | --- |
| Free selection | Without naming PRAXO-CORE, does the coding tool discover it and correctly select or exclude it for the task? |
| Directed integration | When PRAXO-CORE is required, can the tool install, build, test, and satisfy the stated governance requirements? |
| Upgrade and maintenance | Does the generated integration continue to work after a dependency update or application change? |

Record discovery, appropriate selection, installation, build, governed-test
success, repair cost, and observable dependency retention separately. Define
first-generated-attempt success separately from eventual autonomous-session
success. Report sample sizes and repeated trials, tool/model versions, prompts,
package versions, search and execution permissions, budgets, and actual results.
Keep unseen tasks alongside regression tasks. Compare no-skill and installed-skill
conditions separately; an explicitly required dependency is not free-selection
evidence. Correctly excluding an unsuitable framework is a successful decision.

Registry downloads are supporting signals, not proof of adoption. Retention uses
only public or consented observations; unavailable data remains unknown. Set
improvement targets after the baseline, not arbitrary adoption percentages.

### Profiles and Non-goals

Use one Kernel with three [integration levels](../reference/execution-profiles.md):
Standard Embedding names existing configurable embedding behavior; Governed
Execution Profile is a proposed acceptance contract with partial fixture
evidence; Embodied Integration Profile now has a
[proposed design](../reference/embodied-integration.md), but no consumer pilot
has started. Do not create three kernels, runtime switches or release lines.
Governed assembly and the actual Effect PEP enforce the required controls;
ordinary `agent.New` defaults remain compatible. The embodied design adds
obligations to governed integration and cannot weaken them.

Core contracts define local execution semantics. Integration profiles add
deployment requirements, external state mappings, and acceptance criteria;
adapters and products supply the actual external behavior. A profile document
does not itself provide identity authenticity, durable effects, or safety.

Coding-agent skills help development tools integrate the framework. Runtime
skills loaded by an executing agent have separate provenance and trust concerns.
A skill in this repository is not automatically installed in coding tools.
Machine-readable documentation indexes may assist discovery, but do not guarantee
tool support, search ranking, or adoption. A remote MCP service is not a
prerequisite for SDK adoption.

Long-running software and physical operations should first be tested through
existing tool/adapter seams; a new generic asynchronous-action API is not assumed.
An embodied pilot must keep local Run, coordination Task, durable Process, and
robot Mission authority separate. Remote cancellation needs confirmation from its
execution authority; checkpoints do not prove physical effects or exactly-once
execution. Real-time control, emergency stops, safety interlocks, and hardware
drivers remain outside Core.

Do not commit to parallel ROS 2, Dora, and Zenoh implementations, a micro-runtime,
or language-specific production roles before consumer evidence exists. Detailed
cross-product ownership decisions and execution plans belong in the internal
planning repositories, not this public framework roadmap.

## Current Focus

Prioritize verifiable behavior over additional language, provider, or tool counts.
Each row separates the acceptance target Core owns from evidence owned elsewhere.
These are targets, not statements that the work is complete.

| Direction | Core-owned acceptance target | Evidence owned elsewhere |
| --- | --- | --- |
| Release and verification integrity | Documentation and release gates agree with canonical version metadata; skipped tests and stale reports cannot be presented as current passes | Release operators and CI retain raw run records |
| Governed integration | Missing mandatory controls, denied authorization, and security dependency failures prevent execution; final tool arguments remain subject to authorization | NOMIVELA, EIDOVELA, AEGIVELA, and LIMENORA provide registry, identity, policy, and network services; Core supplies interfaces, fakes, and negative tests |
| Context trust | Source and trust distinctions survive Core assembly, compaction, offload, and restore; hostile memory, skills, and tool results do not become trusted instructions in Core tests | PRAXOVELA and memory/retrieval products provide authentic sources and durable lineage |
| Effect semantics and recovery | Core distinguishes intent, attempted execution, business commit, no-effect, and unknown outcome; checkpoints are not transactions; idempotency behavior is tested | RHEOVELA owns durable workflow, worker leases, fencing, and recovery; PRAXOVELA owns tenant-scoped effect ledgers; no exactly-once claim |
| Containment | Core-owned VFS, path, plugin, process-host, and WASM controls are tested, with platform limits and residual risks stated | Deployment OS/network isolation and deployment-level independent review belong to the product or operator |
| Provider and observability evidence | Core supplies event/OpenTelemetry mapping, allowlists, fake-provider conformance, and the workspace session contract | Live providers, collector/OTLP, sampling, and retention are integration evidence; two-provider review gates workspace contract promotion |
| Language support | Contract conformance, behavior coverage, and support level are reported separately; agent-capable implementations target twenty scenarios; unsupported cells remain explicit | Package publication and live operational evidence follow the registry and product records |

Governed integration is contract work in Core. NOMIVELA, EIDOVELA, AEGIVELA,
LIMENORA, and RHEOVELA own the registry, identity, policy, network, and durable
workflow services; Core supplies interfaces, testable fakes, and negative tests.
See [Ecosystem Boundaries](#ecosystem-boundaries).

## Behavior Capability Tiers

### Execution Correctness Priority

Establish the [Execution Correctness Suite](execution-correctness.md) alongside,
not in place of, Behavior Lab. Its proposed EC-01 through EC-14 inventory targets
partial parallel commits, response loss, non-idempotent retry, approval mutation,
revocation, context trust/budgets, cancellation, checkpoint lag, evidence failure,
actual isolation, conflicting resource updates, accepted-versus-completed robot
actions and repeated recovery.

Prioritize mapping existing Core assertions and missing deterministic failures
before adding language/scenario counts. Then add consumer-backed database,
gateway, effect-ledger and real-sandbox integrations, followed by deployment
fault/load validation. The tracks are EC-D (Deterministic), EC-I (Integration)
and EC-O (Operational), not replacements for the existing L1-L6 taxonomy. No
track passes another by implication. The inventory is proposed/not-run as a
suite; it does not claim a runner, fourteen passes, or new effect semantics.

These failures provide acceptance targets for governed/embodied designs without
making ordinary Standard Embedding a mandatory enterprise security profile.

Behavior coverage is tracked separately from contract tier:

| Tier | Languages | Current target |
| --- | --- | --- |
| Agent-capable | Go, Python, TypeScript, Java, Rust, R, C# | All twenty Behavior Lab scenarios; missing cells stay explicit |
| Extended | C, PHP, Fortran, COBOL, Ruby, Elixir, Erlang, C++, Lua | Scenario-by-scenario only with a named consumer and maintainer |
| Optional | Other declared implementations | Outside the behavior program; contract conformance unchanged |

The clean sixteen-language report has 320 passed, 0 unsupported, and no
failures. All sixteen wired languages now cover twenty scenarios in the
source; some parallel-tool cells delegate concurrency to caller-provided batch
callbacks without Core-created threads. Do not treat an unsupported cell as a
failure or a pass, and do not add languages or scenarios solely to raise the
count.

See the [governed execution design](../reference/governed-execution.md) for proposed
boundaries and the [test evidence standard](../contributing/test-evidence.md) for
recording environment, configuration, procedure, data, results, and findings.

## Verification Boundaries

Core tests establish framework behavior. Cross-repository tests establish only
the integrations and versions they actually execute. Historical local service
runs are valuable evidence, but do not certify the current release, independent
reproduction, or production readiness.

Behavior Lab and compatibility reports name the revision they tested. A later
documentation-only commit does not extend that evidence; re-run or re-pin the
report before citing it for a new revision.

New shared security or effect contracts require a named consumer and negative
tests before API promotion. Identity issuance, policy decision services, effect
ledgers, and durable workflow engines remain integration responsibilities.
The design does not by itself change default behavior or the public API.

## Ecosystem Boundaries

PRAXO-CORE is a reusable execution kernel, not the product platform. The
PRAXOVELA family composes it through the same public contracts available to any
consumer. This page states ownership boundaries, not a product roadmap.

| Capability | Owner | Core responsibility |
| --- | --- | --- |
| Product runtime, tenant data, UX, deployment | PRAXOVELA (AXON Core) | Expose the agent, tool, policy, stream, checkpoint, and workspace APIs; keep product state out of the framework |
| Graph/subgraph execution, durable workflow, worker leases, fencing, recovery | RHEOVELA | Provide agent-node, session, stream, and adapter contracts; do not add a graph runtime |
| Agent registry, agent IDs, authority binding, discovery | NOMIVELA | Define the registry client boundary; do not operate a registry |
| Agent identity, enrollment, attestation, PoP tokens, verified context | EIDOVELA | Define identity verification hooks; do not issue credentials |
| Policy decisions, execution grants, approvals, revocation, obligations, security evidence | AEGIVELA | Define authorizer, grant, and policy-enforcement points; do not operate a PDP or durable approval store |
| North-south network boundary and reverse ingress | LIMENORA | Remain deployable behind a gateway; do not add a network control plane |
| Capability governance, runtime profiles, memory, and event transport | MODUREGIS, SYNDOVELA, Mnemovela/GNOSIVELA, Harmovela | Provide optional adapter contracts only when a named consumer and negative tests exist |

Identity issuance, policy decision services, effect ledgers, durable workflow
engines, and network gateways remain integration responsibilities. A Core test
does not certify a product deployment, and a product integration does not
widen the Core API.

## Compatibility Commitments

Keep the public Go API small, preserve the MIT boundary, and require consumers
and tests for new contracts. Core implementations must not widen the Go API merely to simplify
a port. See [compatibility policy](compatibility-policy.md),
[Core support](../languages/support.md), and [language policy](../contributing/language-policy.md).

## Delivered Work

See [release history](../releases/index.md), the
[verification evidence index](verification-evidence.md), and the
[changelog](https://github.com/axisvela/praxo-core/blob/main/CHANGELOG.md).
Optional adapter evaluation is not equivalent to live production verification.
