# C# Examples

- [`structured-output/`](structured-output/): published NuGet
  `Praxo.Core==0.6.0` with validated JSON output and a deterministic
  `--test` mode.
- [`mcp/`](mcp/): in-process MCP client with a deterministic `--test` mode.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure, with a deterministic `--test` mode.
- [`event-sink/`](event-sink/): lifecycle and tool events through `MultiSink`
  and `FilterSink`, with a deterministic `--test` mode.
- [`streaming/`](streaming/): delta callbacks that reconstruct the final output,
  with a deterministic `--test` mode.
- [`checkpoint/`](checkpoint/): application-owned checkpoint storage with
  allowlisted payload encoding.
- [`retry/`](retry/): retry transient model failures with bounded attempts and
  a deterministic `--test` mode.
- [`identity-policy/`](identity-policy/): bind a trusted principal to policy and
  reject effects before execution.
- [`service/`](service/): standard-library HTTP service with principal, tenant,
  policy, and a deterministic `--test` mode.

The example installs a published package. It does not require a repository
checkout or a project reference replacement.
