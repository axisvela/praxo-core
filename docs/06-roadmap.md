# Roadmap Detail

See [ROADMAP.md](https://github.com/axisvela/praxo-core/blob/main/ROADMAP.md)
for the public roadmap.

## Release Discipline

- `0.x` may break interfaces with a minor bump.
- `1.0.0` freezes the exported interfaces.
- Each release updates `CHANGELOG.md` and `VERSION`.
- Each release states the supported PRAXOVELA range.

## Compatibility Gates

| Gate | Requirement |
| --- | --- |
| 0.2.0 | every primitive has a conformance test |
| 0.3.0 | PRAXOVELA builds against the module |
| 0.5.0 | restart and duplicate-firing tests pass |
| 0.15.0 | plugin hosts, Manifest v1, contract TCK, path containment, and context budget pass their tests |
| 0.16.0 | canonical package paths, deprecated aliases, and exported API inventory |
| 1.0.0 | API freeze, security review, external integrator example, SBOM/checksums |
| 1.1.0 | context management parity: summarization, offload, `AGENTS.md`, prompt cache hooks (released 2026-10-18) |
| 1.2.0 | delegation/execution parity: async/fork subagents, virtual FS backend, delete/glob/grep (released 2026-10-18) |
| 1.3.0 | harness profiles, rubric/evaluation middleware, optional JS interpreter (released 2026-10-18) |
| 1.4.0 | structured output, tool selection, PII, fallback, tool retry, call limits (released 2026-10-18) |
| 1.5.0 | HITL approve/edit/reject/respond decisions (released 2026-10-18) |
| 1.6.0 | capability package split, typed streams, session resume, checkpoint allowlist (released 2026-10-18) |
| 1.7.0 | context editing and todo/planning middleware (released 2026-10-18) |
| 2.0.0 | v2 module path; API functionally identical to 1.7.0 (released 2026-10-18) |
| 2.1.0 | adoption surface: adapters, docs site, recipes, benchmarks, reference app (released 2026-10-22) |
| 2.2.0 | ecosystem depth: protocol adapters, multi-agent composition, examples, security fixes (released 2026-10-23) |
| 2.3.0 | execution correctness: event-driven subagents, real parallelism, bounded concurrency (released 2026-10-23) |
| 2.3.1 | post-release hardening: A2A gRPC round trip, wait/prune snapshot, docs gate (released 2026-10-23) |
| 2.3.2 | provider and security recipe hardening; Gemini stream candidate isolation (released 2026-10-23) |
| 2.3.3 | final tool authorization, fail-fast release gates, independent module security checks (released 2026-10-24) |
| 2.3.4 | JSON Schema subset semantics and HTTP client failure-path coverage (released 2026-10-24) |
| 2.3.5 | scheduler disable waits for in-flight dispatch (released 2026-10-24) |
| 2.3.6 | formatter runtime and mutation fixes (released 2026-10-24) |
| 2.4.0 | adoption surface: streaming quickstart, MCP resources/prompts example, recall benchmark (released 2026-10-24) |
| 2.5.0 | framework hardening: conformance package, localfs special-path checks, schema and trust docs (released 2026-10-24) |

Post-1.0 items are competitive harness parity and adoption work, not 1.0
blockers. They are sequenced after the stable API and release gates.

The current release is `2.5.0`. It adds the additive `pkg/conformance` package,
hardens local VFS special-path validation, and publishes the event/OTel schema
and plugin trust/SBOM handoff docs. Workspace adapters remain offline evaluation
modules; they are not live-verified or promoted to `pkg/`.

## Post-2.5 Framework Priorities

`2.5.0` completed the conformance suite and the first containment hardening
pass. Remaining framework work, without changing existing exported `pkg/...`
declarations:

- adversarial containment for TOCTOU, Linux process trees, and WASM CPU limits
- the OpenTelemetry reference example (#3)
- the remote worker contract with RHEOVELA
- live verification of the E2B, Daytona, OpenSandbox, and CubeSandbox adapters
- live CubeSandbox E2B-profile confirmation after the offline compatibility
  review
- compatibility and deprecation rules for exported contracts
- an independent implementation running the conformance suite

## Long-Term Technical Direction

- **3-6 months:** containment hardening, conformance suite, and remote worker
  contract.
- **6-12 months:** stable event/OpenTelemetry schemas, compatibility rules, and
  independent implementations.
- **12+ months:** frozen `pkg/...` API, verifiable consumers for every feature,
  and an intact MIT boundary.

Product adoption, case studies, and go-to-market planning are tracked outside
this repository.

## Adoption Surface (delivered)

- streaming quickstart and reference app
- event-driven subagent waits, real `flow.Parallel` concurrency, and bounded
  multi-agent supervision
- OpenAI-compatible, MCP, OTel, Anthropic, Gemini, Harmovela, A2A, and
  multi-agent adapters/modules
- NOETIVELA, Mnemovela, GNOSIVELA, AEGIVELA, LIMENORA, and RHEOVELA recipes
- bilingual docs site, multi-agent guidance, adoption guide, and recipes
- benchmarks, release notes, and published-module consumer checks

## Evidence

- unit tests
- interface conformance tests
- consumer build tests
- release notes
- SBOM and checksums
