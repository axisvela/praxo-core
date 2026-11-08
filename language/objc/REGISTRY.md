# PRAXO-CORE Objective-C Registry Introduction

**Status:** source-only. Source version `0.1.1`, source
tag `objc/v0.1.1`. Published registry version: not published. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

Objective-C is a native Core implementation with source tag `objc/v0.1.1`. It passes all eleven shared vector groups and includes the native agent loop, context compaction, memory store, path policy, checkpoint allowlist, tool selection, tool-call parsing, and opt-in PII redaction, structured output validation, and call limits. Vector coverage does not establish full Core parity or production readiness.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core-objc` |
| Registry | Source |
| Source version | `0.1.1` |
| Published registry version | not published |
| Install (published) | not published |
| Install (source/release prepared) | `See README/SETUP.md` |
| Source tag | `objc/v0.1.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/objc/ |

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
