# Contract Parity Inventory

Newer Core implementations keep their inventories under `spec/parity/` (`rust.md`, `c.md`,
`csharp.md`, `php.md`, `swift.md`, and the bridge files). This page remains the
inventory for the original core languages.

Every exported Go contract package and core symbol must have a row here. The Core
columns record declared feature coverage relative to Go; they do not assert full
Go feature parity. The parity linter consumes this file and the
`api/<version>.txt` snapshots.

## Maturity Dimensions

Keep these dimensions separate:

- **Contract conformance:** the Core's declared vector groups, API snapshot, and
  build/tests pass.
- **Feature coverage:** the rows below relative to Go. `partial` and `planned`
  rows are expected outside a Core's declared scope and may remain inside a
  declared subset.
- **Operational evidence:** real runtime, provider, platform, failure, and
  production observations. A source tag or a `complete` matrix label does not
  supply this evidence.

`complete` in [the language matrix](languages.md) means declared-scope
conformance, not that every parity row is `parity`.

## Status Legend

| Status | Meaning | Released Core gate |
| --- | --- | --- |
| `planned` | Mapped in the design, outside the currently implemented subset | allowed when outside the declared scope |
| `partial` | Implemented for a subset of the row's Go symbols or behaviors | allowed with a documented scope gap; not a vector-conformance failure by itself |
| `parity` | Declared symbols implemented and covered by vectors | required for the row's declared scope |
| `n/a` | Not applicable; the language provides its own harness | allowed |

A released Core must pass its declared vector groups, API snapshot, and language
tests. Its inventory must record known `planned` or `partial` rows honestly.
Those rows describe relative feature coverage and do not by themselves fail a
release; the matrix notes and the declared scope decide what the release claims.

## Package Inventory

| Go package | Contract area | Python | TypeScript | Java | Phase |
| --- | --- | --- | --- | --- | --- |
| `pkg/model` | model, provider, messages, usage | partial | partial | partial | P1 |
| `pkg/tool` | tool, registry, gateway, middleware, retry | partial | partial | partial | P1 |
| `pkg/tool/jsonschema` | JSON Schema subset | partial | partial | partial | P1 |
| `pkg/toolcall` | tool-call parsing | parity | parity | parity | P1 |
| `pkg/agent` | agent loop and options | partial | partial | partial | P1 |
| `pkg/agent/types` | run state, hooks, session | partial | partial | partial | P1 |
| `pkg/agent/stream` | typed stream projections | parity | parity | parity | P1 |
| `pkg/agent/context` | budget, compact, offload, AGENTS.md | parity | parity | partial | P1 |
| `pkg/agent/middleware` | call limits, fallback, PII, structured output, tool selection, todos | partial | partial | partial | P1 |
| `pkg/agent/hitl` | interrupt decisions | planned | planned | planned | P2 |
| `pkg/agent/evaluation` | rubric evaluation | planned | planned | planned | P2 |
| `pkg/agent/delegation` | subagent manager | planned | planned | planned | P2 |
| `pkg/event` | event envelope and sinks | partial | partial | partial | P1 |
| `pkg/memory` | memory store and context assembler | partial | partial | partial | P1 |
| `pkg/checkpoint` | checkpoint store and allowlist | partial | partial | partial | P1 |
| `pkg/policy` | authorization and path containment | parity | parity | parity | P1 |
| `pkg/prompt` | prompt templates | planned | planned | planned | P2 |
| `pkg/flow` | runnable, chain, parallel | planned | planned | planned | P2 |
| `pkg/retriever` | document retrieval contract | planned | planned | planned | P2 |
| `pkg/httpclient` | retry-capable HTTP transport | planned | planned | planned | P2 |
| `pkg/sandbox` | sandbox and interpreter seam | planned | planned | planned | P2 |
| `pkg/vfs` | virtual filesystem backend | planned | planned | planned | P2 |
| `pkg/vfs/localfs` | confined local backend | planned | planned | planned | P2 |
| `pkg/vfs/vfstools` | `fs.*` tools | planned | planned | planned | P2 |
| `pkg/formatter` | formatter registry | planned | planned | planned | P3 |
| `pkg/scheduler` | schedule contract and engine | planned | planned | planned | P3 |
| `pkg/plugin` | Manifest v1, lifecycle, registry | planned | planned | planned | P3 |
| `pkg/plugin/bridge` | host to provider adapters | planned | planned | planned | P3 |
| `pkg/plugin/host/process` | process host and envelopes | planned | planned | planned | P3 |
| `pkg/plugin/host/wasm` | WASM host and guest ABI | planned | planned | planned | P4 |
| `pkg/plugin/tck` | host conformance kit | n/a | n/a | n/a | P3 |
| `pkg/conformance` | reusable Go contract checks | n/a | n/a | n/a | n/a |

`pkg/conformance` and `pkg/plugin/tck` are Go harnesses. Each Core implementation ships its own
runner over `spec/vectors`; a Go-only harness is not a parity gap.

## Seed Symbol Inventory

This is the starting set for the symbol-level linter. Expand it as each Core implementation
lands. Names in the Core columns are required targets, not current symbols.

| Go symbol | Kind | Python | TypeScript | Java | Phase |
| --- | --- | --- | --- | --- | --- |
| `model.Model` | interface | `praxo.model.Model` | `Model` | `Model` | P1 |
| `model.Provider` | interface | `praxo.model.Provider` | `Provider` | `Provider` | P1 |
| `model.ChatModel` | type | `praxo.model.ChatModel` | `ChatModel` | `ChatModel` | P1 |
| `model.Message` | struct | `praxo.model.Message` | `Message` | `Message` | P1 |
| `model.ContentBlock` | struct | `praxo.model.ContentBlock` | `ContentBlock` | `ContentBlock` | P1 |
| `model.Request` | struct | `praxo.model.Request` | `Request` | `Request` | P1 |
| `model.Response` | struct | `praxo.model.Response` | `Response` | `Response` | P1 |
| `model.ToolCall` | struct | `praxo.model.ToolCall` | `ToolCall` | `ToolCall` | P1 |
| `model.ToolSpec` | struct | `praxo.model.ToolSpec` | `ToolSpec` | `ToolSpec` | P1 |
| `model.Usage` | struct | `praxo.model.Usage` | `Usage` | `Usage` | P1 |
| `tool.Tool` | interface | `praxo.tool.Tool` | `Tool` | `Tool` | P1 |
| `tool.Registry` | struct | `praxo.tool.Registry` | `Registry` | `Registry` | P1 |
| `tool.Gateway` | interface | `praxo.tool.Gateway` | `Gateway` | `Gateway` | P1 |
| `event.Event` | struct | `praxo.event.Event` | `Event` | `Event` | P1 |
| `event.Sink` | interface | `praxo.event.Sink` | `Sink` | `Sink` | P1 |
| `policy.Hook` | interface | `praxo.policy.Hook` | `Hook` | `Hook` | P1 |
| `policy.Decision` | struct | `praxo.policy.Decision` | `Decision` | `Decision` | P1 |
| `memory.Store` | interface | `praxo.memory.Store` | `Store` | `Store` | P1 |
| `memory.Record` | struct | `praxo.memory.Record` | `MemoryRecord` | `Record` | P1 |
| `memory.Frame` | type | `praxo.memory.Frame` | `Frame` | `Frame` | P1 |
| `checkpoint.Checkpoint` | struct | `praxo.checkpoint.Checkpoint` | `Checkpoint` | `Checkpoint` | P1 |
| `checkpoint.Store` | interface | `praxo.checkpoint.Store` | `Store` | `Store` | P1 |
| `agent.Agent` | struct | `praxo.agent.Agent` | `Agent` | `Agent` | P1 |
| `agent.Options` | struct | `praxo.agent.Options` | `AgentOptions` | `AgentOptions` | P1 |
| `agent.New` | function | `praxo.agent.Agent` | `Agent` | `Agent.create` | P1 |
| `agent/types.Session` | struct | `praxo.agent.Session` | `Session` | `Session` | P1 |
| `agent/types.Result` | struct | `praxo.agent.Result` | `Result` | `Result` | P1 |
| `agent/stream.StreamPart` | struct | `praxo.stream.StreamPart` | `StreamPart` | `Streams.StreamPart` | P1 |
| `agent/types.Middleware` | struct | `praxo.middleware.Middleware` | `Middleware` | `Middleware` | P1 |
| `agent/types.RunState` | struct | `praxo.middleware.RunState` | `RunState` | `RunState` | P1 |
| `agent/types.ModelCall` | struct | `praxo.middleware.ModelCall` | `ModelCall` | `ModelCall` | P1 |
| `agent/types.ToolCall` | struct | `praxo.middleware.ToolCall` | `ToolCall` | `ToolCall` | P1 |
| `agent/types.ToolResult` | struct | `praxo.middleware.ToolResult` | `ToolResult` | `ToolResult` | P1 |
| `agent/context.MaxAgentsMDBytes` | const | `praxo.context.MaxAgentsMDBytes` | `MAX_AGENTS_MD_BYTES` | `Contexts.MAX_AGENTS_MD_BYTES` | P1 |
| `agent/context.ErrContextBudget` | var | `praxo.errors.ContextBudgetError` | `ContextBudgetError` | `ContextBudgetException` | P1 |
| `agent/context.EstimateTokens` | function | `praxo.context.estimate_tokens` | `estimateTokens` | `Contexts.estimateTokens` | P1 |
| `agent/context.LoadAgentsMD` | function | `praxo.context.load_agents_md` | `loadAgentsMd` | `Contexts.loadAgentsMd` | P1 |
| `agent/context.ContextBudget` | struct | `praxo.context.ContextBudget` | `ContextBudget` | `ContextBudget` | P1 |
| `agent/context.ContextCompactor` | interface | `praxo.context.ContextCompactor` | `ContextCompactor` | `ContextCompactor` | P1 |
| `agent/context.ModelSummarizer` | struct | `praxo.context.ModelSummarizer` | `ModelSummarizer` | `ModelSummarizer` | P1 |
| `agent/context.OffloadFunc` | type | `praxo.context.OffloadFunc` | `OffloadFunc` | `OffloadFunc` | P1 |
| `agent/context.Offloader` | interface | `praxo.context.Offloader` | `Offloader` | `Offloader` | P1 |
| `agent/middleware.CallLimitMiddleware` | function | `praxo.middleware.call_limit_middleware` | `callLimitMiddleware` | `Middleware.callLimit` | P1 |
| `agent/middleware.FallbackModel` | function | `praxo.middleware.fallback_model` | `fallbackModel` | `Middleware.fallbackModel` | P1 |
| `agent/middleware.PIIMiddleware` | function | `praxo.middleware.pii_middleware` | `piiMiddleware` | `Middleware.pii` | P1 |
| `agent/middleware.PIIRedactor` | struct | `praxo.middleware.PIIRedactor` | `PiiRedactor` | `PiiRedactor` | P1 |
| `agent/middleware.PIIRule` | struct | `praxo.middleware.PIIRule` | `PiiRule` | `PiiRule` | P1 |
| `agent/middleware.NewPIIRule` | function | `praxo.middleware.new_pii_rule` | `newPiiRule` | `PiiRule.of` | P1 |
| `agent/middleware.DefaultPIIRules` | function | `praxo.middleware.default_pii_rules` | `defaultPiiRules` | `PiiRules.defaults` | P1 |
| `agent/middleware.StructuredOutput` | struct | `praxo.middleware.StructuredOutput` | `StructuredOutput` | `StructuredOutput` | P1 |
| `agent/middleware.ToolSelector` | interface | `praxo.middleware.ToolSelector` | `ToolSelector` | `ToolSelector` | P1 |
| `agent/middleware.ToolSelectionMiddleware` | function | `praxo.middleware.tool_selection_middleware` | `toolSelectionMiddleware` | `Middleware.toolSelection` | P1 |
| `agent/middleware.ModelToolSelector` | struct | `praxo.middleware.ModelToolSelector` | `ModelToolSelector` | `ModelToolSelector` | P1 |
| `tool/jsonschema.Schema` | struct | `praxo.jsonschema.Schema` | `Schema` | `Schema` | P1 |
| `tool/jsonschema.ValidationError` | struct | `praxo.jsonschema.ValidationError` | `ValidationError` | `ValidationError` | P1 |
| `tool/jsonschema.FromJSON` | function | `praxo.jsonschema.from_json` | `fromJson` | `Schemas.fromJson` | P1 |
| `toolcall.ParseToolCall` | function | `praxo.toolcall.parse_tool_call` | `parseToolCall` | `ToolCalls.parse` | P1 |
| `toolcall.StripToolCallMarkup` | function | `praxo.toolcall.strip_tool_call_markup` | `stripToolCallMarkup` | `ToolCalls.stripMarkup` | P1 |
| `toolcall.ParseInputJSON` | function | `praxo.toolcall.parse_input_json` | `parseInputJson` | `ToolCalls.parseInputJson` | P1 |

## Linter Rules

The parity linter:

1. Reads `api/<version>.txt` and fails on any exported `pkg/...` package absent
   from the package inventory.
2. Discovers released Core scopes from [the language matrix](languages.md) and
   fails when a released Core has no split parity inventory. It does not require
   every P1 package row to be `parity`: `partial` and `planned` rows are feature
   coverage records, not vector-conformance results.
3. Validates declared rows and fails when a row names a symbol that the Core
   does not export, when a status/phase is invalid, or when a `parity`/`partial`
   row lacks its language symbol.
4. Fails when a wire artifact in `spec/wire` references an event, error, stream
   kind, or plugin field absent from the Go reference.
5. Does not compare source signatures; it compares symbol existence and vector
   behavior. It does not infer runtime, provider, or production maturity from a
   parity row or matrix label.

## Change Process

1. Add or change the Go declaration.
2. Update `spec/wire/` if the wire changed.
3. Add the package or symbol row here.
4. Add a vector for the behavior.
5. Confirm the Go runner passes.
6. Implement in each Core implementation. Record `parity` when the declared
   behavior is implemented and covered; record a documented `partial` gap when
   it is intentionally outside the current scope.

See [Multilingual Core design](../docs/contributing/sdk-design.md).
