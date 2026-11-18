# Swift Examples

- [`consumer/`](consumer/): deterministic `record` tool with an explicit tool
  scope, policy allow/deny checks, and zero effects on denial.
- [`live-model/`](live-model/): OpenAI-compatible `get_time` tool example with a
  caller-selected endpoint and model.
- [`representative-chain/`](representative-chain/): deterministic MCP, policy,
  delegation, OTel/Harmovela, and edited-denial end-to-end chain.
- [`advanced-delegation/`](advanced-delegation/): application-level governance
  negative checks for delegated child agents.
- [`checkpoint/`](checkpoint/): checkpoint allowlist round trip.
- [`event-sink/`](event-sink/): event fan-out and tool-only filtering.
- [`hitl/`](hitl/): approve or edit a write call before it takes effect.
- [`identity-policy/`](identity-policy/): trusted principal and policy checks.
- [`mcp/`](mcp/): in-process MCP transport.
- [`provider-fallback/`](provider-fallback/): primary/fallback model selection.
- [`retry/`](retry/): bounded transient-failure retry.
- [`service/`](service/): transport-neutral request handler.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history recovery.
- [`streaming/`](streaming/): streamed chunk reconstruction.
- [`structured-output/`](structured-output/): JSON Schema output validation.

Each directory has its own README with the exact run command.
