# PRAXO-CORE R Registry Introduction

**Status:** r-universe 0.6.1 published; CRAN not published. Source version `0.6.1`, source
tag `r/v0.6.1`. Published registry version: `0.6.1`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

R implementation of the PRAXO-CORE contract.

## Package

| Field | Value |
| --- | --- |
| Package | `praxocore` |
| Registry | [r-universe](https://axisvela.r-universe.dev/praxocore) |
| Source version | `0.6.1` |
| Published registry version | `0.6.1` |
| Install (published) | `install.packages("praxocore", repos = "https://axisvela.r-universe.dev")` |
| Install (source/release prepared) | `install.packages("praxocore", repos = "https://axisvela.r-universe.dev")` |
| Source tag | `r/v0.6.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/r/ |

## Coding-agent entry

- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](../../docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
