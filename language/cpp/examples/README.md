# C++ Examples

- [`consumer/`](consumer/): deterministic allow/deny governed tool path.
- [`live-model/`](live-model/): OpenAI-compatible endpoint with one `get_time`
  tool and a caller-owned transport seam.
- [`hitl/`](hitl/): approval and edit-reauthorization for a write tool.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history save, reload,
  and continue.
- [`checkpoint/`](checkpoint/): checkpoint allowlist round trip.
- [`event-sink/`](event-sink/): lifecycle and tool events.
- [`identity-policy/`](identity-policy/): trusted principal and policy denial.
- [`mcp/`](mcp/): MCP client with a deterministic fixture.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure.
- [`retry/`](retry/): retry transient model failures.
- [`service/`](service/): application-owned HTTP service shape.
- [`streaming/`](streaming/): streaming callbacks.
- [`structured-output/`](structured-output/): JSON Schema validation.

Build the examples from the C++ CMake build directory.
