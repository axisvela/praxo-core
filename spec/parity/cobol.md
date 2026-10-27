# COBOL Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released native Core SDK. All 62 vectors in eleven groups, native agent tests,
JSON tests, contract boundary tests, tooling tests, and the API declaration
snapshot pass locally. The remote `cobol-conformance` job passes; `cobol/v0.1.0`
is the released tag. `partial` does not claim every optional Go hook, provider
adapter, or full model surface. See `language/cobol/README.md` for bounded JSON, pattern,
path-policy, plugin, and middleware behavior.

| Go symbol | COBOL symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Model` | model callback program | partial | P1 |
| `model.Message` | `px-messages` in `history.cpy` | partial | P1 |
| `model.Request` | `px-session` callback input | partial | P1 |
| `model.Response` | `px-response` | partial | P1 |
| `model.Usage` | `px-input-tokens`, `px-output-tokens` | partial | P1 |
| `tool.Tool` | tool dispatcher callback, `px-call`, `px-tool-result` | partial | P1 |
| `event.Event` | `px-event` | partial | P1 |
| `event.Sink` | event callback program | partial | P1 |
| `event.FilterSink` | `praxo-event` filter operation | partial | P1 |
| `event.MultiSink` | `praxo-event` multi operation | partial | P1 |
| `policy.Policy` | policy callback program, `px-action` | partial | P1 |
| `policy.Decision` | policy callback status | partial | P1 |
| `policy.PathChecker` | `praxo-policy`, `praxo-path-normalize` | partial | P1 |
| `memory.Record` | `px-mem-record` fields | partial | P1 |
| `memory.Store` | `praxo-memory` | partial | P1 |
| `checkpoint.Allowlist` | `praxo-checkpoint` | partial | P1 |
| `agent.Agent` | `praxo-run` | partial | P1 |
| `agent.Options` | `px-options` | partial | P1 |
| `agent.RunResult` | `px-result` | partial | P1 |
| `agent.Session` | `px-session` | partial | P1 |
| `agent/context.ContextBudget` | `praxo-context` | partial | P1 |
| `agent/context.EstimateTokens` | `praxo-context` estimate operation | partial | P1 |
| `agent/stream.StreamPart` | `praxo-stream`, `stream.cpy` | partial | P1 |
| `toolcall.ParseToolCall` | `praxo-toolcall` parse operation | partial | P1 |
| `toolcall.ParseInputJSON` | `praxo-toolcall` parse-input operation | partial | P1 |
| `toolcall.StripToolCallMarkup` | `praxo-toolcall` strip operation | partial | P1 |
| `tool/jsonschema.Schema` | `praxo-jsonschema`, `praxo-schema-scalar`, `praxo-schema-visit` | partial | P1 |
| `plugin.ParseManifest` | `praxo-plugin` | partial | P1 |
| `agent/middleware.CallLimitMiddleware` | `praxo-middleware` call-limit operation | partial | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `praxo-middleware` tool-selection operation | partial | P1 |
| `agent/middleware.FallbackModel` | `praxo-middleware` fallback operation | partial | P1 |
| `agent/middleware.StructuredOutput` | `praxo-middleware` structured operation | partial | P1 |
| `agent/middleware.PIIMiddleware` | `praxo-middleware` pii and pii-json operations | partial | P1 |
| `tool.Registry` | not implemented | planned | P1 |

SDK-local utilities with no new normative contract symbols:
`praxo-json-parse`, `praxo-json-generate`, `praxo-json-string`,
`praxo-json-quote`, `praxo-json-slice`, and `praxo-utf8`. They use the bounded
records in `language/cobol/copy/json.cpy`; see `language/cobol/README.md` for capacities and local
statuses. `praxo-agent-vector` and its callback programs live under
`language/cobol/tests/` and are conformance adapters over `praxo-run`, not public API.
