# Haskell Examples

- [`consumer/`](consumer/): deterministic allow/deny governed tool path with an
  explicit tool scope and policy.
- [`live-model/`](live-model/): OpenAI-compatible adapter with a `get_time` tool
  and a documented HTTP transport seam.
- [`identity-policy/`](identity-policy/): trusted principal binding and
  pre-effect denial.
- [`checkpoint/`](checkpoint/): checkpoint allowlist round trip.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history recovery from
  an in-memory checkpoint store.
- [`hitl/`](hitl/): human approval, edit, reject, and respond decisions for a
  write tool.
- [`event-sink/`](event-sink/): lifecycle and tool events.
- [`provider-fallback/`](provider-fallback/): fallback after a primary model
  failure.
- [`retry/`](retry/): bounded retry for transient model failures.
- [`streaming/`](streaming/): incremental chunk assembly.
- [`structured-output/`](structured-output/): JSON Schema validation.
- [`mcp/`](mcp/): caller-owned MCP-shaped transport.
- [`service/`](service/): embedded service boundary.

Run examples with `runghc -ilanguage/haskell/src <path>` from the repository
root.
