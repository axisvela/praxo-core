# Rust Examples

- [`consumer/`](consumer/): published crates.io `praxo-core==0.8.0` starter with
  deterministic allow/deny checks.
- [`live-model/`](live-model/): source-mode OpenAI-compatible endpoint using
  the optional `http-ureq` feature and `qwen3.5:4b` via Ollama.
- [`hitl/`](hitl/): approval and edit-reauthorization for a write tool.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history save, reload,
  and continue.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure, with a deterministic check.
- [`event-sink/`](event-sink/): lifecycle and tool events through `MultiSink`
  and `FilterSink`, with a deterministic check.
- [`streaming/`](streaming/): delta callbacks that reconstruct the final output,
  with a deterministic check.
- [`mcp/`](mcp/): in-process MCP transport for deterministic tool discovery and
  tool calls.
- [`structured-output/`](structured-output/): JSON Schema validation with a
  deterministic valid/invalid output check.
- [`checkpoint/`](checkpoint/): application-owned checkpoint storage with
  allowlisted payload encoding.
- [`retry/`](retry/): retry transient model failures with bounded attempts and a
  deterministic check.
- [`service/`](service/): standard-library HTTP service with principal, tenant,
  policy, and a deterministic check.
- [`identity-policy/`](identity-policy/): bind a trusted principal to policy and
  reject effects before execution.

The deterministic examples use published crate `praxo-core = "0.8.0"`. The
`live-model` example uses the repository source because `http-ureq` is not in the
published `0.8.0` crate.
