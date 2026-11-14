# PRAXO-CORE MATLAB/Octave shared core Registry Introduction

**Status:** shared implementation; use MATLAB or Octave package. Source version `0.5.0`, source
tag `matlab/v0.5.0 and octave/v0.5.0`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Shared implementation used by the MATLAB and Octave packages. It is not a standalone package; use the MATLAB or Octave registry entry.

## Package

| Field | Value |
| --- | --- |
| Package | `shared implementation` |
| Registry | shared source |
| Source version | `0.5.0` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `Not a standalone package` |
| Source tag | `matlab/v0.5.0 and octave/v0.5.0` |
| Tier | Shared |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/ |

## Coding-agent entry

- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
