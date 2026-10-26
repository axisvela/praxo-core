# COBOL Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Unreleased native Core implementation in progress. Agent regression tests and
JSON utility tests pass locally, but no complete vector group coverage or Core
release is claimed. Full assistant tool-call history and wire event identifiers
are not yet represented by the experimental records.

| Go symbol | COBOL symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Model` | model program callback | partial | P1 |
| `model.Message` | `px-messages` in `history.cpy` | partial | P1 |
| `model.Request` | `px-session` callback input | partial | P1 |
| `model.Response` | `px-response` | partial | P1 |
| `model.Usage` | `px-input-tokens`, `px-output-tokens` | partial | P1 |
| `tool.Tool` | tool dispatcher callback, `px-call`, `px-tool-result` | partial | P1 |
| `event.Event` | `px-event` | partial | P1 |
| `event.Sink` | event program callback | partial | P1 |
| `policy.Policy` | policy program callback, `px-action` | partial | P1 |
| `agent.Agent` | `praxo-run` | partial | P1 |
| `agent.Options` | `px-options` | partial | P1 |
| `agent.RunResult` | `px-result` | partial | P1 |
| `agent.Session` | `px-session` | partial | P1 |
| `tool.Registry` | not implemented | planned | P1 |
| `memory.Store` | not implemented | planned | P1 |
| `checkpoint.Allowlist` | not implemented | planned | P1 |
| `agent/context.ContextBudget` | not implemented | planned | P1 |
| `toolcall.ParseToolCall` | not implemented | planned | P1 |
| `tool/jsonschema.Schema` | not implemented | planned | P1 |
| `plugin.ParseManifest` | not implemented | planned | P1 |
| `agent/stream.StreamPart` | not implemented | planned | P1 |
| `agent/middleware.CallLimitMiddleware` | not implemented | planned | P1 |

Native SDK utilities with no new normative contract symbols:
`praxo-json-parse`, `praxo-json-string`, `praxo-json-quote`,
`praxo-json-generate`, and `praxo-utf8`. They use the bounded records in
`copy/json.cpy`; see `cobol/README.md` for capacities and local statuses.
