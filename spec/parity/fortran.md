# Fortran Parity

- Tier: core
- SPEC_VERSION: 0.2.0

Unreleased native Core candidate. All 62 vectors in eleven groups, native
regression tests, and the API declaration snapshot pass locally. Remote CI and
release evidence are pending. `partial` does not claim every optional Go hook,
provider integration, or full wire/model surface. See `fortran/README.md` for
bounded JSON, pattern, path-policy, PII, and stream limitations.

| Go symbol | Fortran symbol | Status | Phase |
| --- | --- | --- | --- |
| `model.Model` | `praxo_interfaces.model` | partial | P1 |
| `model.Message` | `praxo_types.message`, `text_message` | partial | P1 |
| `model.Request` | `praxo_types.request` | partial | P1 |
| `model.Response` | `praxo_types.response` | partial | P1 |
| `model.Usage` | `praxo_types.usage` | partial | P1 |
| `tool.Tool` | `praxo_interfaces.tool` | partial | P1 |
| `tool.Registry` | `praxo_interfaces.registry` | partial | P1 |
| `event.Event` | `praxo_types.event` | partial | P1 |
| `event.Sink` | `praxo_interfaces.event_sink` | partial | P1 |
| `event.FilterSink` | `praxo_runtime.filter_sink` | partial | P1 |
| `event.MultiSink` | `praxo_runtime.multi_sink` | partial | P1 |
| `policy.Policy` | `praxo_interfaces.policy`, `praxo_types.action` | partial | P1 |
| `policy.Decision` | `praxo_types.decision` | partial | P1 |
| `memory.Record` | `praxo_runtime.memory_record` | partial | P1 |
| `memory.Store` | `praxo_runtime.memory_store` | partial | P1 |
| `agent/context.ContextBudget` | `praxo_context.context_budget` | partial | P1 |
| `agent/context.EstimateTokens` | `praxo_context.estimate_tokens` | partial | P1 |
| `agent.Agent` | `praxo_agent.run_agent` | partial | P1 |
| `agent.Options` | `praxo_agent.agent_options` | partial | P1 |
| `agent.RunResult` | `praxo_types.run_result` | partial | P1 |
| `agent.Session` | `praxo_types.session` | partial | P1 |
| `checkpoint.Allowlist` | `praxo_checkpoint.checkpoint_allowlist` | partial | P1 |
| `policy.PathChecker` | `praxo_policy.path_checker`, `path_grant` | partial | P1 |
| `agent/stream.StreamPart` | `praxo_stream.stream_part`, `stream_kinds` | partial | P1 |
| `toolcall.ParseToolCall` | `praxo_toolcall.parse_tool_call`, `parsed_tool_call` | partial | P1 |
| `toolcall.ParseInputJSON` | `praxo_toolcall.parse_input_json` | partial | P1 |
| `toolcall.StripToolCallMarkup` | `praxo_toolcall.strip_markup` | partial | P1 |
| `tool/jsonschema.Schema` | `praxo_schema.validate_schema`, `validation_error` | partial | P1 |
| `plugin.ParseManifest` | `praxo_plugin.parse_manifest`, `plugin_manifest` | partial | P1 |
| `agent/middleware.CallLimitMiddleware` | `praxo_middleware.call_limit`, agent options hook | partial | P1 |
| `agent/middleware.ToolSelectionMiddleware` | `praxo_middleware.tool_selection`, agent options hook | partial | P1 |
| `agent/middleware.FallbackModel` | `praxo_middleware.fallback_model` | partial | P1 |
| `agent/middleware.StructuredOutput` | `praxo_middleware.structured_output`, `structured_model` | partial | P1 |
| `agent/middleware.PIIMiddleware` | `praxo_middleware.redact_email`, `redact_json_email`, agent options hook | partial | P1 |

SDK-local utilities do not add new normative contract symbols:
`praxo_json` provides native JSON documents, node traversal, encoding, exact
decimal equality, and numeric access. `praxo_unicode` provides UTF-8 validation,
JSON quoting/decoding, and Unicode length. `praxo_pattern.match_pattern` is an
explicitly bounded ASCII pattern subset. `praxo_types.sdk_error`, `string_item`,
`string_value`, and `same_string` support these native APIs.
