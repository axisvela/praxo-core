# API Freeze Inventory

**Status:** pre-1.0 audit for `0.16.0`. The exported API is not frozen until
`1.0.0`.

## Audit Result

- Exported declarations: **436**
- Exported declarations without a doc comment: **0**
- Scope: `pkg/...`; examples, tests, unexported receiver methods, and testdata
  are excluded.
- The audit covers exported functions, methods on exported types, types,
  constants, and variables.

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
| `pkg/agent` | `Agent`, `Options`, `Profile`, `Middleware`, `Hooks`, `ContextBudget`, `Session`, `Result`, statuses, budgets |
| `pkg/checkpoint` | `Checkpoint`, `Store`, recovery types |
| `pkg/event` | `Event`, `Sink`, multi/filter/publisher sinks |
| `pkg/flow` | `Runnable`, `Chain`, `Parallel` |
| `pkg/formatter` | `Formatter`, detection/execution registry |
| `pkg/httpclient` | retry-capable client and auth/tracing options |
| `pkg/memory` | `Store`, `Record`, `Frame`, context assembler |
| `pkg/model` | `Model`, `Provider`, messages, tool specs, response format |
| `pkg/plugin` | Manifest v1, contract kinds, lifecycle, registry, scope, limits, telemetry |
| `pkg/plugin/bridge` | host-to-provider adapters and codecs |
| `pkg/plugin/host/process` | process host and platform supervisors |
| `pkg/plugin/host/wasm` | WASM host and guest ABI |
| `pkg/plugin/tck` | lifecycle, registry, and host conformance checks |
| `pkg/policy` | `Hook`, `Decision`, `PathChecker`, path grants |
| `pkg/prompt` | `Template`, `ChatTemplate` |
| `pkg/retriever` | `Document`, `Retriever` |
| `pkg/sandbox` | `Sandbox`, `Spec`, `Result` |
| `pkg/scheduler` | schedule definitions and engine |
| `pkg/tool` | `Tool`, `Registry`, middleware, gateway |
| `pkg/tool/jsonschema` | JSON Schema validator |
| `pkg/toolcall` | tool-call parsing and markup stripping |

## Deprecated Aliases

The following paths were deprecated in `0.16.0`:

| Deprecated path | Canonical path |
| --- | --- |
| `pkg/output` | `pkg/toolcall` |
| `pkg/format` | `pkg/formatter` |
| `pkg/tool/schema` | `pkg/tool/jsonschema` |

PRAXOVELA migrated to the canonical paths in `0.16.0`. The aliases may be
removed no earlier than `1.0.0`; removal requires a release note and a migration
line in `docs/05-compatibility.md`.

## Compatibility Rules

- Additive exported changes are allowed in minor releases.
- Removing or changing an exported signature/field requires a major release
  after `1.0.0`.
- Interface additions require a major release unless the interface is
  documented as extensible.
- JSON tags on exported structs are part of the contract.
- Typed constant string values are part of the contract.

## Open Questions Before 1.0

1. `toolcall.ToolCall` includes optional product governance metadata
   (`Operation`, `Resource`, `Risk`, `Reason`, `IdempotencyKey`). They are
   documented as pass-through metadata; decide whether 1.0 keeps them or moves
   them to a product extension.
2. `checkpoint.Message` duplicates a subset of `model.Message` to avoid a
   package dependency. Confirm this boundary is intentional.
3. `tool.Gateway` and `pkg/plugin/bridge` both adapt external tool providers.
   Document which seam new integrations should use.
4. Decide whether the deprecated aliases are removed in `1.0.0` or kept through
   the `1.x` line and removed in `2.0.0`.

## 1.0 Gate Checklist

- [x] exported API inventory
- [x] every exported declaration has a doc comment
- [ ] open questions resolved and documented
- [ ] API diff review against `0.16.0`
- [ ] compatibility and migration notes published
- [ ] security review and threat model
- [ ] external integrator example
- [ ] SBOM, checksums, and signed release gate
