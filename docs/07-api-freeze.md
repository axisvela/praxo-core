# API Freeze Inventory

**Status:** v2 module-path audit for `2.0.0`; `2.1.0` and `2.2.0` add no
`pkg/...` declarations. `2.3.0` adds `SubagentManager.Wait` and
`SubagentManager.Prune`; all other declarations are unchanged. `2.3.1` through
`2.4.0` add no `pkg/...` declarations. `2.5.0` adds the additive
`pkg/conformance` package. The `1.0.0` surface remains frozen; new declarations
are additive.

## Audit Result

- Exported declarations: **701**
- Exported declarations without a doc comment: **0**
- Scope: `pkg/...`; examples, tests, unexported receiver methods, and testdata
  are excluded.
- The audit covers exported functions, methods on exported types, types,
  constants, and variables.

The `pkg/agent` root keeps type aliases for the capability packages, so
existing `agent.*` imports remain source-compatible while implementation
lives in capability subpackages.

## Freeze Scope

The `1.0.0` compatibility promise covers:

- exported interfaces and their method sets
- exported struct field names and JSON tags
- exported function signatures
- exported constants and typed string values
- error sentinels and typed error codes
- wire formats documented as contracts (plugin Manifest v1 and host envelopes)

Not covered:

- concrete adapters, product wiring, and Janus/Vulcan internals
- unexported helpers
- examples
- fields explicitly documented as experimental

## Package Inventory

| Package | Stable surface |
| --- | --- |
| `pkg/agent` | `Agent`, `Options`, `Profile`, `New`, compatibility aliases for capability types |
| `pkg/agent/context` | budgets, compaction, summarization, offload, `AGENTS.md` |
| `pkg/agent/delegation` | async subagent manager, modes, waiting, and terminal-task pruning |
| `pkg/agent/evaluation` | rubrics and evaluators |
| `pkg/agent/hitl` | interrupt actions, decisions, handlers |
| `pkg/agent/middleware` | call limits, fallback, PII, structured output, tool selection, context editing, todos |
| `pkg/agent/stream` | typed stream parts |
| `pkg/agent/types` | shared run-state contracts |
| `pkg/checkpoint` | `Checkpoint`, `Store`, recovery types |
| `pkg/conformance` | reusable VFS, memory, sandbox, event, policy, gateway, model, tool, and retriever contract checks |
| `pkg/event` | `Event`, `Sink`, multi/filter/publisher sinks |
| `pkg/flow` | `Runnable`, `Chain`, `Parallel` |
| `pkg/formatter` | `Formatter`, detection/execution registry |
| `pkg/httpclient` | retry-capable client and auth/tracing options |
| `pkg/memory` | `Store`, `Record`, `Frame`, context assembler |
| `pkg/model` | `Model`, `Provider`, messages, tool specs, response format, `CacheHint`, `ProviderProfile` |
| `pkg/plugin` | Manifest v1, contract kinds, lifecycle, registry, scope, limits, telemetry |
| `pkg/plugin/bridge` | host-to-provider adapters and codecs |
| `pkg/plugin/host/process` | process host and platform supervisors |
| `pkg/plugin/host/wasm` | WASM host and guest ABI |
| `pkg/plugin/tck` | lifecycle, registry, and host conformance checks |
| `pkg/policy` | `Hook`, `Decision`, `PathChecker`, path grants |
| `pkg/prompt` | `Template`, `ChatTemplate` |
| `pkg/retriever` | `Document`, `Retriever` |
| `pkg/sandbox` | `Sandbox`, `Spec`, `Result`, optional `Interpreter` |
| `pkg/scheduler` | schedule definitions and engine |
| `pkg/tool` | `Tool`, `Registry`, middleware, retry, gateway |
| `pkg/tool/jsonschema` | JSON Schema validator |
| `pkg/vfs` | `Backend`, entries, matches, optional executor |
| `pkg/vfs/localfs` | confined local-directory backend |
| `pkg/vfs/vfstools` | `fs.*` tools backed by a vfs backend |
| `pkg/toolcall` | tool-call parsing and markup stripping |

## Deprecated Aliases

The following paths were deprecated in `0.16.0`:

| Deprecated path | Canonical path |
| --- | --- |
| `pkg/output` | `pkg/toolcall` |
| `pkg/format` | `pkg/formatter` |
| `pkg/tool/schema` | `pkg/tool/jsonschema` |

PRAXOVELA migrated to the canonical paths in `0.16.0`. The aliases are removed
in `1.0.0`; the release note and migration line live in
`docs/05-compatibility.md`.

## Compatibility Rules

- Additive exported changes are allowed in minor releases.
- Removing or changing an exported signature/field requires a major release
  after `1.0.0`.
- Interface additions require a major release unless the interface is
  documented as extensible.
- JSON tags on exported structs are part of the contract.
- Typed constant string values are part of the contract.

## Resolved Decisions

1. `toolcall.ToolCall` keeps `Operation`, `Resource`, `Risk`, `Reason`, and
   `IdempotencyKey` in 1.0 as optional pass-through product metadata. The
   parser does not interpret them; removing them would break PRAXOVELA's
   product API. Revisit in 2.0.
2. `checkpoint.Message` deliberately stays a dependency-free serialization
   shape rather than aliasing `model.Message`.
3. `tool.Gateway` is the seam for product-owned external gateways such as
   Janus. `pkg/plugin/bridge` is the seam for `plugin.Host` implementations.
   Both package docs state the distinction.
4. The deprecated aliases are removed in `1.0.0`; PRAXOVELA already migrated in
   `0.16.0`.

## 1.0 Gate Checklist

- [x] exported API inventory
- [x] every exported declaration has a doc comment
- [x] open questions resolved and documented
- [x] API diff review against `0.16.0`
- [x] compatibility and migration notes published
- [x] `0.16.0 -> 1.0.0` diff reviewed: only the three deprecated alias packages
  are removed; no other exported changes
- [x] framework threat model and security hardening (independent review pending)
- [x] external integrator example
- [x] SBOM/checksum/release-check tooling verified locally
- [x] Linux/Windows/macOS CI and race observed green (2026-10-18)
- [x] release published with SBOM/checksums (annotated tag; GPG signing unavailable)
