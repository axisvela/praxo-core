# TypeScript Examples

- [`consumer/`](consumer/): published npm `@axisvela/praxo-core@0.5.0` starter
  with deterministic allow/deny checks.
- [`live-model/`](live-model/): published npm package connected to an
  OpenAI-compatible endpoint through `get_time`.
- [`structured-output/`](structured-output/): validated JSON output with
  `StructuredOutput` and a deterministic fake-model test.
- [`mcp/`](mcp/): stdio MCP client with a local deterministic server.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure, with deterministic tests.
- [`event-sink/`](event-sink/): lifecycle and tool events through `MultiSink`
  and `FilterSink`, with deterministic tests.
- [`streaming/`](streaming/): delta callbacks that reconstruct the final output,
  with a deterministic fake streaming model.
- [`checkpoint/`](checkpoint/): application-owned checkpoint storage with
  allowlisted payload encoding.
- [`retry/`](retry/): retry transient model failures with bounded attempts and
  deterministic tests.
- [`identity-policy/`](identity-policy/): bind a trusted principal to policy and
  reject effects before execution.
- [`service/`](service/): standard-library HTTP service with principal, tenant,
  policy, and deterministic tests.

The examples install a published package. They do not require a repository
checkout or local package replacement.
