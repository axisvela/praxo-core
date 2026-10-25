# Python API Reference

Normative contract: [`spec/`](../spec/README.md). This page lists the public
Python surface. The checked-in snapshot is `api/<version>.txt`.

## `praxo.model`

| Symbol | Purpose |
| --- | --- |
| `Model` | Async `generate(request) -> Response` protocol |
| `StreamingModel` | Adds `generate_stream(request, on_delta)` |
| `Provider` | Chat-oriented `chat` / `chat_stream` contract |
| `ChatModel` | Adapts a `Provider` to `Model` |
| `Message`, `ContentBlock`, `ToolCall`, `ToolSpec` | Wire-compatible model types |
| `Request`, `Response`, `Usage` | Request/response envelopes |
| `ResponseFormat`, `CacheHint` | Provider-neutral structured output and cache hints |

## `praxo.tool`

| Symbol | Purpose |
| --- | --- |
| `Tool` | `name`, `description`, async `invoke(args)` |
| `FuncTool` | Function-backed tool |
| `Registry` | Name-indexed tool registry with sorted specs |
| `Gateway`, `GatewayInfo`, `GatewayTool` | External tool gateway seam |

## `praxo.event`

| Symbol | Purpose |
| --- | --- |
| `Event` | Lifecycle event envelope |
| `Sink` | Async `emit(event)` |
| `MultiSink` | Fail-fast fan-out |
| `FilterSink` | Predicate-filtered forwarding |

## `praxo.policy`

| Symbol | Purpose |
| --- | --- |
| `Hook`, `FuncHook` | Async authorization hook |
| `Action`, `Decision` | Authorization input/output |
| `PathGrant`, `PathChecker` | Deny-by-default filesystem containment |

## `praxo.memory`

| Symbol | Purpose |
| --- | --- |
| `Store` | Async `put` / `search` contract |
| `Record`, `Frame` | Typed memory record |
| `MemoryStore` | In-memory store, newest-first search |
| `ContextAssembler` | Query-relevant memory retrieval |

## `praxo.checkpoint`

| Symbol | Purpose |
| --- | --- |
| `Checkpoint`, `Message`, `RunSnapshot`, `EffectCursor` | Durable snapshot types |
| `Store` | Async checkpoint store contract |
| `Allowlist` | Typed envelope marshal/unmarshal allowlist |

## `praxo.context`

| Symbol | Purpose |
| --- | --- |
| `ContextBudget` | Deterministic prompt compaction |
| `estimate_tokens` | Provider-neutral token estimate |
| `ContextCompactor`, `ModelSummarizer` | Optional summarization pass |
| `Offloader`, `OffloadFunc` | Large tool-result offload seam |
| `load_agents_md` | Bounded `AGENTS.md` loading |
| `MaxAgentsMDBytes` | Combined AGENTS.md limit |

## `praxo.middleware`

| Symbol | Purpose |
| --- | --- |
| `Middleware`, `ModelCall`, `ToolCall`, `ToolResult`, `RunState` | Middleware contracts |
| `call_limit_middleware` | Per-run model/tool call budgets |
| `fallback_model` | Fallback model middleware |
| `PIIRedactor`, `PIIRule`, `default_pii_rules`, `pii_middleware` | PII redaction |
| `StructuredOutput` | JSON schema binding, validation, repair |
| `ToolSelector`, `ModelToolSelector`, `tool_selection_middleware` | Per-run tool narrowing |

## `praxo.agent`

| Symbol | Purpose |
| --- | --- |
| `Agent` | Governed async agent loop |
| `AgentOptions` | Model, tools, events, policy, context, middleware, limits |
| `Session`, `Result` | Run scope and outcome |

## `praxo.toolcall`

| Symbol | Purpose |
| --- | --- |
| `parse_tool_call` | Parse supported model tool-call formats |
| `strip_tool_call_markup` | Remove recognized tool-call markup |
| `parse_input_json` | Tolerant JSON object parsing |

## `praxo.jsonschema`

| Symbol | Purpose |
| --- | --- |
| `Schema`, `ValidationError` | Documented JSON Schema subset |
| `from_json`, `validate` | Parse and validate helpers |

## `praxo.plugin`

| Symbol | Purpose |
| --- | --- |
| `parse_manifest` | Strict Manifest v1 parse and validation |
| `validate_trust` | Signed/unsigned trust profile |
| `KINDS`, `STATES`, `EVENT_KINDS`, `CALL_ERROR_CODES` | Frozen enums |

## `praxo.adapters.openaicompat`

| Symbol | Purpose |
| --- | --- |
| `OpenAIConfig` | Base URL, key, model, timeout, headers |
| `OpenAICompatibleModel` | Non-streaming and SSE streaming adapter |

## Snapshot

```bash
python api-snapshot.py
python api-snapshot.py --check
```
