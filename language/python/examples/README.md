# Python Examples

- [`consumer/`](consumer/): published PyPI `praxo-core==0.6.0` starter with
  deterministic allow/deny checks.
- [`live-model/`](live-model/): published PyPI package connected to an
  OpenAI-compatible endpoint through `get_time`.
- [`structured-output/`](structured-output/): validated JSON output with
  `StructuredOutput` and a deterministic fake-model test.
- [`mcp/`](mcp/): stdio MCP client with a local deterministic server.
- [`service/`](service/): standard-library HTTP service with principal, policy,
  and fake-model tests.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure, with deterministic tests.

The examples install a published package. They do not require a repository
checkout or local package replacement.
