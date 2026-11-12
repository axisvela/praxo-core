# PRAXO-CORE Haskell Registry Introduction

**Status:** published. Source version `0.3.0`, source
tag `haskell/v0.3.0`. Published registry version: `0.3.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native Haskell Core. It implements all eleven declared vector groups and does not call Go or another Core. It includes a native callback-based agent loop with tools, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, plugin manifest parsing, and runtime helpers.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [Hackage](https://hackage.haskell.org/package/praxo-core-0.3.0) |
| Source version | `0.3.0` |
| Published registry version | `0.3.0` |
| Install (published) | `cabal install praxo-core` |
| Install (source/release prepared) | `cabal install praxo-core` |
| Source tag | `haskell/v0.3.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/haskell/ |

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
