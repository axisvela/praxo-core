# Delphi / Free Pascal Examples

- [`consumer/`](consumer/): deterministic `record` tool with an explicit tool
  scope, policy allow/deny checks, and zero effects on denial.
- [`live-model/`](live-model/): OpenAI-compatible `get_time` tool example with a
  caller-selected endpoint and model.
- [`checkpoint/`](checkpoint/): checkpoint allowlist round trip.
- [`hitl/`](hitl/): approve, edit, reject, and respond interrupt decisions.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history save and restore.
- [`event-sink/`](event-sink/): event fan-out and tool-only filtering.
- [`identity-policy/`](identity-policy/): trusted principal and policy checks.
- [`mcp/`](mcp/): in-process MCP transport.
- [`provider-fallback/`](provider-fallback/): primary/fallback model selection.
- [`retry/`](retry/): bounded transient-failure retry.
- [`service/`](service/): transport-neutral request handler.
- [`streaming/`](streaming/): streamed chunk reconstruction.
- [`structured-output/`](structured-output/): JSON Schema output validation.

Each directory has its own README with the exact run command.
