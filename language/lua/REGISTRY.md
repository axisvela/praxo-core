# PRAXO-CORE Lua Registry Introduction

**Status:** published. Source version `0.4.0-1`, source tag
`lua/v0.4.0`. Registry pages are release snapshots; verify the published
version before relying on a feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This rock is its native Lua Core: an agent loop with tool registration and dispatch, policy hooks, typed events, memory, checkpoints, context budgets, middleware, JSON Schema validation, plugin manifest parsing, and human-in-the-loop interrupt decisions.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo-core` |
| Registry | [LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core) |
| Version | `0.4.0-1` |
| Install | `luarocks install praxo-core` |
| Source tag | `lua/v0.4.0` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/lua/ |

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
