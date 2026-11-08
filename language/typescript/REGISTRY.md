# PRAXO-CORE TypeScript Registry Introduction

**Status:** published. Source version `0.2.2`, source
tag `typescript/v0.2.2`. Published registry version: `0.2.2`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is a dependency-free TypeScript framework for building tool-using AI agents. It provides the agent runtime, not a model or hosted service, so you keep control of your models, tools, storage, and sandboxing.

## Package

| Field | Value |
| --- | --- |
| Package | `@axisvela/praxo-core` |
| Registry | [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.2.2) |
| Source version | `0.2.2` |
| Published registry version | `0.2.2` |
| Install (published) | `npm install @axisvela/praxo-core@0.2.2` |
| Install (source/release prepared) | `npm install @axisvela/praxo-core@0.2.2` |
| Source tag | `typescript/v0.2.2` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/typescript/ |

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
