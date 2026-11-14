# Python Examples

- [`consumer/`](consumer/): published PyPI `praxo-core==0.7.0` starter with
  deterministic allow/deny checks.
- [`live-model/`](live-model/): published PyPI package connected to an
  OpenAI-compatible endpoint through `get_time(zone)`.
- [`hitl/`](hitl/): approval and edit-reauthorization for a write tool.
- [`structured-output/`](structured-output/): validated JSON output with
  `StructuredOutput` and a deterministic fake-model test.
- [`mcp/`](mcp/): stdio MCP client with a local deterministic server.
- [`service/`](service/): standard-library HTTP service with principal, policy,
  and fake-model tests.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure, with deterministic tests.
- [`event-sink/`](event-sink/): lifecycle and tool events through `MultiSink`
  and `FilterSink`, with deterministic tests.
- [`streaming/`](streaming/): delta callbacks that reconstruct the final output,
  with a deterministic fake streaming model.
- [`checkpoint/`](checkpoint/): application-owned checkpoint storage with
  allowlisted payload encoding.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history save, reload,
  and continue.
- [`retry/`](retry/): retry transient model failures with bounded attempts and
  deterministic tests.
- [`identity-policy/`](identity-policy/): bind a trusted principal to policy and
  reject effects before execution.

Most examples install a published package and do not require a repository
checkout or local package replacement. The HITL example is a source-mode
approval demonstration with a deterministic model.
