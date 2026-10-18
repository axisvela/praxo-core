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
| 1.0.0 | security review and external integrator example |

## Evidence

- unit tests
- interface conformance tests
- consumer build tests
- release notes
- SBOM and checksums
