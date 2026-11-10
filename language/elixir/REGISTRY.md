# PRAXO-CORE Elixir Registry Introduction

**Status:** published. Source version `0.4.1`, source
tag `elixir/v0.4.1`. Published registry version: `0.4.1`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its native Elixir Core with source tag `elixir/v0.4.1`. It passes all eleven shared vector groups with `Elixir 1.20.4` on `Erlang/OTP 29` and includes the native agent loop, context compaction, memory store, path policy, checkpoint allowlist, tool-call parsing, and opt-in tool selection, PII redaction, structured output validation, call limits, and human-in-the-loop interrupt decisions. Vector coverage does not establish full Core parity or production readiness.

## Package

| Field | Value |
| --- | --- |
| Package | `praxo_core` |
| Registry | [Hex](https://hex.pm/packages/praxo_core) |
| Source version | `0.4.1` |
| Published registry version | `0.4.1` |
| Install (published) | `{:praxo_core, "~> 0.4.1"}` |
| Install (source/release prepared) | `{:praxo_core, "~> 0.4.1"}` |
| Source tag | `elixir/v0.4.1` |
| Tier | Core |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/elixir/ |

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
