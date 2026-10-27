# Fortran Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Released native Core source tag `fortran/v0.2.0`. All 62 vectors in eleven
groups, native regression tests, and the API declaration snapshot pass locally;
the remote `fortran-conformance` job runs the same suite. `partial` marks a
surface that covers the vector behavior and common path but not every optional Go
hook, provider integration, or full wire/model surface. See
`language/fortran/README.md` for bounded JSON, pattern, path-policy, and stream
limitations.

| Go symbol | Fortran symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Model` | `praxo_interfaces.model` | parity | P1 |
| `model.Message` | `praxo_types.message`, `text_message` | parity | P1 |
| `model.Request` | `praxo_types.request` | parity | P1 |
| `model.Response` | `praxo_types.response` | parity | P1 |
| `model.Usage` | `praxo_types.usage` | parity | P1 |
| `tool.Tool` | `praxo_interfaces.tool` | parity | P1 |
| `tool.Registry` | `praxo_interfaces.registry` | parity | P1 |
| `event.Event` | `praxo_types.event` | parity | P1 |
| `event.Sink` | `praxo_interfaces.event_sink` | parity | P1 |
| `event.FilterSink` | `praxo_runtime.filter_sink` | parity | P1 |
| `event.MultiSink` | `praxo_runtime.multi_sink` | parity | P1 |
| `policy.Policy` | `praxo_interfaces.policy`, `praxo_types.action` | parity | P1 |
| `policy.Decision` | `praxo_types.decision` | parity | P1 |
| `memory.Record` | `praxo_runtime.memory_record` | parity | P1 |
| `memory.Store` | `praxo_runtime.memory_store` | parity | P1 |
| `agent/context.ContextBudget` | `praxo_context.context_budget` | parity | P1 |
| `agent/context.EstimateTokens` | `praxo_context.estimate_tokens` | parity | P1 |
| `agent.Agent` | `praxo_agent.run_agent` | parity | P1 |
| `agent.Options` | `praxo_agent.agent_options` | parity | P1 |
| `agent.RunResult` | `praxo_types.run_result` | parity | P1 |
| `agent.Session` | `praxo_types.session` | parity | P1 |
| `checkpoint.Allowlist` | `praxo_checkpoint.checkpoint_allowlist` | parity | P1 |
| `policy.PathChecker` | `praxo_policy.path_checker`, `path_grant` | parity | P1 |
| `agent/stream.StreamPart` | `praxo_stream.stream_part`, `stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `praxo_toolcall.parse_tool_call`, `parsed_tool_call` | parity | P1 |
| `toolcall.ParseInputJSON` | `praxo_toolcall.parse_input_json` | parity | P1 |
| `toolcall.StripToolCallMarkup` | `praxo_toolcall.strip_markup` | parity | P1 |
| `tool/jsonschema.Schema` | `praxo_schema.validate_schema`, `validation_error` | partial | P1 |
| `plugin.ParseManifest` | `praxo_plugin.parse_manifest`, `plugin_manifest` | parity | P1 |
| `agent/middleware.CallLimitMiddleware` | `praxo_middleware.call_limit`, agent options hook | parity | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `praxo_middleware.tool_selection`, agent options hook | parity | P1 |
| `agent/middleware.FallbackModel` | `praxo_middleware.fallback_model` | parity | P1 |
| `agent/middleware.StructuredOutput` | `praxo_middleware.structured_output`, `structured_model` | parity | P1 |
| `agent/middleware.PIIMiddleware` | `praxo_middleware.redact_pii`, `redact_json_pii`, agent options hook | parity | P1 |

SDK-local utilities do not add new normative contract symbols:
`praxo_json` provides native JSON documents, node traversal, encoding, exact
decimal equality, and numeric access. `praxo_unicode` provides UTF-8 validation,
JSON quoting/decoding, and Unicode length. `praxo_pattern.match_pattern` is an
explicitly bounded ASCII pattern subset. `praxo_types.sdk_error`, `string_item`,
`string_value`, and `same_string` support these native APIs.
