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

Post-1.0 items are competitive harness parity and adoption work, not 1.0
blockers. They are sequenced after the stable API and release gates.

## Adoption Workstream

The `2.1.0` workstream keeps the `pkg/...` API frozen while improving the path
from discovery to production:

- quickstart and reference app
- OpenAI-compatible and MCP adapters
- NOETIVELA, Mnemovela, and GNOSIVELA SDK recipes
- bilingual docs site, adoption guide, and recipes
- benchmarks and release notes
- community files and good first issues

## Evidence

- unit tests
- interface conformance tests
- consumer build tests
- release notes
- SBOM and checksums
