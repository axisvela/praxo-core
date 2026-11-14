# R Examples

- [`consumer/`](consumer/): published r-universe `praxocore` starter with
  deterministic allow/deny checks.
- [`live-model/`](live-model/): OpenAI-compatible endpoint with `qwen3.5:4b` via
  Ollama.
- [`structured-output/`](structured-output/): validated JSON output with a
  deterministic test.
- [`mcp/`](mcp/): stdio MCP client over a caller-supplied transport.
- [`service/`](service/): standard-library HTTP service shape with principal and
  policy checks.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure, with a deterministic check.
- [`event-sink/`](event-sink/): lifecycle and tool events, with a deterministic
  check.
- [`streaming/`](streaming/): delta callbacks with a deterministic stream model.
- [`checkpoint/`](checkpoint/): application-owned checkpoint storage with
  allowlisted payload encoding.
- [`retry/`](retry/): retry transient model failures with bounded attempts.
- [`identity-policy/`](identity-policy/): bind a trusted principal to policy and
  reject effects before execution.

The examples install the published `praxocore` package or run against the
repository source. They do not require a source checkout for installation.
