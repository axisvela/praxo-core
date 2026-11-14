# Erlang Examples

- [`hitl/`](hitl/): approval and edit-reauthorization for a write tool.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history save, reload,
  and continue.
- [`checkpoint/`](checkpoint/): checkpoint allowlist round trip.
- [`event-sink/`](event-sink/): lifecycle and tool events.
- [`identity-policy/`](identity-policy/): trusted principal and policy denial.
- [`mcp/`](mcp/): stdio MCP client with a deterministic server.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure.
- [`retry/`](retry/): retry transient model failures.
- [`service/`](service/): application-owned HTTP service shape.
- [`streaming/`](streaming/): streaming callbacks.
- [`structured-output/`](structured-output/): JSON Schema validation.

The deterministic examples run against the compiled runtime in
`language/erlang/build/ebin`.
