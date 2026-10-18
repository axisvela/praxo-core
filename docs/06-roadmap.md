# Roadmap Detail

See [ROADMAP.md](../ROADMAP.md) for the public roadmap.

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
| 1.2.0 | delegation/execution parity: async/fork subagents, virtual FS backend, delete/glob/grep |
| 1.3.0 | harness profiles, rubric/evaluation middleware, optional JS interpreter |

Post-1.0 items are competitive harness parity, not 1.0 blockers. They are
sequenced after the stable API and release gates.

## Evidence

- unit tests
- interface conformance tests
- consumer build tests
- release notes
- SBOM and checksums
