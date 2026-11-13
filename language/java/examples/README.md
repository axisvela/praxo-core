# Java Examples

- [`consumer/`](consumer/): published Maven Central
  `com.axisvela:praxo-core:0.7.0` starter with deterministic allow/deny checks.
- [`live-model/`](live-model/): published Maven artifact connected to an
  OpenAI-compatible endpoint through `get_time`.
- [`structured-output/`](structured-output/): validated JSON output with
  `StructuredOutput` and a deterministic fake-model test.
- [`event-sink/`](event-sink/): lifecycle and tool events through `Sink.multi`
  and `Sink.filter`, with a deterministic check.
- [`streaming/`](streaming/): delta callbacks that reconstruct the final output,
  with a deterministic check.
- [`retry/`](retry/): retry transient model failures with bounded attempts and a
  deterministic check.
- [`identity-policy/`](identity-policy/): bind a trusted principal to policy and
  reject effects before execution.

The examples resolve a published artifact. They do not require a repository
checkout or local package replacement.
