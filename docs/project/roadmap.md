# Public Roadmap

Current core release: `2.5.2`. This is an **execution-kernel contract roadmap**:
it covers the contracts and verified behavior Core owns, and names evidence that
belongs to products or integrations. It is not a delivery schedule or a promise
that every Core implementation supports every feature.

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
