# PRAXO-CORE Go Registry Introduction

**Status:** published. Source version `v2.6.0`, source
tag `v2.6.0`. Published registry version: `v2.6.0`. Registry
pages are release snapshots; verify the published version before relying on a
feature.

## Positioning

[English](README.md) | [简体中文](README.zh-CN.md)

## Package

| Field | Value |
| --- | --- |
| Package | `github.com/axisvela/praxo-core/v2` |
| Registry | [Go module proxy / pkg.go.dev](https://pkg.go.dev/github.com/axisvela/praxo-core/v2) |
| Source version | `v2.6.0` |
| Published registry version | `v2.6.0` |
| Install (published) | `go get github.com/axisvela/praxo-core/v2@v2.6.0` |
| Install (source/release prepared) | `go get github.com/axisvela/praxo-core/v2@v2.6.0` |
| Source tag | `v2.6.0` |
| Tier | Core (reference) |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/ |

## Coding-agent entry

- [llms.txt](llms.txt): compact machine-readable entry for this language.
- [llms.md](llms.md): Markdown version of the same entry.
- [Coding-agent contract](docs/getting-started/coding-agents.md): explicit
  scope, final-argument authorization, denial tests, and verification commands.

## Boundaries

- PRAXO-CORE is an embeddable, MIT-licensed execution kernel, not a hosted
  model, workflow engine, identity provider, or safety controller.
- Do not infer exactly-once execution, complete sandbox isolation, production
  security certification, live-provider behavior, or physical safety from this
  package.
- Check the registry page and source tag for the exact version; source READMEs
  and canonical documentation may be newer than a published registry page.
