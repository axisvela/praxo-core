# PRAXO-CORE Primitives

| Package | Contract | Typical adapter |
| --- | --- | --- |
| `pkg/model` | `Model.Generate`, `Provider.Chat/ChatStream`, `ModelRouter`, `ChatModel`, `CacheHint`, `ProviderProfile` | PRAXOVELA provider router |
| `pkg/agent` | `Agent.Run`, middleware, hooks, budgets, `ContextCompactor`, `Offloader`, `LoadAgentsMD`, `SubagentManager`, `RubricMiddleware`, `StructuredOutput`, `ToolSelectionMiddleware`, `PIIMiddleware`, `FallbackModel`, `CallLimitMiddleware` | PRAXOVELA agent loop |
| `pkg/checkpoint` | `Checkpoint`, `Store.Save/Load/List`, recovery report | PRAXOVELA checkpoint store |
| `pkg/httpclient` | retry-capable HTTP transport with auth, tracing, and decoding | PRAXOVELA adapters |
| `pkg/tool` | `Tool`, `Registry`, `SpecProvider`, `Middleware`, `Retry`, `Gateway` | Janus Gateway tools |
| `pkg/memory` | `Store.Put/Search`, `MemoryStore`, `ContextAssembler`, `RemoteStore` | Mnemovela |
| `pkg/event` | `Sink.Emit`, `MultiSink`, `FilterSink`, `PublisherSink` | Harmovela / Argus Trace |
| `pkg/policy` | `Hook.Authorize`, `PathChecker` read/write containment | AEGIVELA / Archon Guard |
| `pkg/sandbox` | `Sandbox.Run`, optional `Interpreter.Eval` | Vulcan Forge |
| `pkg/scheduler` | `Scheduler.Add/Remove/List`; cron engine extracted from PRAXOVELA | PRAXOVELA durable scheduler |
| `pkg/toolcall` | `ParseToolCall`, `StripToolCallMarkup`, `ParseInputJSON` | model-output parsing |
| `pkg/tool/jsonschema` | JSON Schema validation | tool input/output validation |
| `pkg/flow` | `Runnable`, `Chain`, `Parallel` | prompt/agent composition |
| `pkg/prompt` | `Template`, `ChatTemplate` | prompt assembly |
| `pkg/retriever` | `Document`, `Retriever` | Mnemovela/GNOSIVELA retrieval |
| `pkg/formatter` | code formatter registry | PRAXOVELA formatting tools |
| `pkg/vfs` | `Backend`, confined local backend, filesystem tools | PRAXOVELA file tools |
| `pkg/plugin` | manifest v1, contract kinds, `Host.Invoke`, `Lifecycle`, `AdapterRegistry` | PRAXOVELA runtime plugin plane |
| `pkg/plugin/host/process` | process host, platform supervisors, JSON-Lines envelopes | PRAXOVELA process plugins |
| `pkg/plugin/host/wasm` | WASM host over wazero | PRAXOVELA WASM plugins |
| `pkg/plugin/bridge` | `Host` to `tool`/`model`/`policy`/`memory`/`sandbox` adapters | framework consumers |
| `pkg/plugin/tck` | lifecycle, registry, and host conformance assertions | host/provider implementers |

`pkg/toolcall` holds model-output tool-call parsing. `pkg/output`,
`pkg/format`, and `pkg/tool/schema` are deprecated aliases removed in `1.0.0`;
new code should import `pkg/toolcall`, `pkg/formatter`, and
`pkg/tool/jsonschema`.

See [Plugin authoring](10-plugin-authoring.md) for Manifest v1, the process/WASM
host protocol, and the conformance kit.

## Tool Contract

A tool has a name, description, and `Invoke(ctx, args)`. Tool specs are exposed
to the model through the registry. Arguments are JSON-compatible maps.

## Memory Contract

Memory is typed by frame: event, decision, experience, procedure, workspace
state, constraint, intention. The framework does not dictate retention or
admission; adapters do.

## Event Contract

Events are lifecycle facts, not logs. Consumers may publish them to Harmovela
or persist them in Argus Trace.

## Policy Contract

Every model generation and tool invocation can be authorized. Denial fails
closed. The framework does not implement policy; it enforces the hook result.

## Scheduler Contract

The framework defines schedules. A runtime owns durable firing and execution.
The scheduling contract is intentionally separate from the agent loop.
