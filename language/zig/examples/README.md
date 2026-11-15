# Zig Examples

- [`consumer/`](consumer/): deterministic allow/deny consumer using the Zig Core
  agent loop.
- [`live-model/`](live-model/): OpenAI-compatible endpoint using a deterministic
  local model service.
- [`checkpoint/`](checkpoint/): application-owned checkpoint storage with
  allowlisted payload encoding.
- [`event-sink/`](event-sink/): lifecycle and tool events through sink
  composition.
- [`retry/`](retry/): retry transient model failures with bounded attempts.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure.
- [`streaming/`](streaming/): delta callbacks that reconstruct the final output.
- [`structured-output/`](structured-output/): JSON Schema validation with a
  deterministic valid/invalid output check.
- [`identity-policy/`](identity-policy/): bind a trusted principal to policy and
  reject effects before execution.
- [`service/`](service/): standard-library HTTP service with principal, tenant,
  and policy checks.
- [`mcp/`](mcp/): in-process MCP transport for deterministic tool discovery and
  tool calls.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history save, reload,
  and continue.
- [`hitl/`](hitl/): approve a write tool, then edit the arguments and observe
  reauthorization denial before any effect.

The examples build against the repository source with the `praxo` module
mapping from `language/zig/src/praxo.zig`.
