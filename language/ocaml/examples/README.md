# OCaml Examples

- [`consumer/`](consumer/): repository Core with a deterministic model and
  allow/deny policy checks.
- [`live-model/`](live-model/): OpenAI-compatible adapter wired through
  `PRAXO_BASE_URL` with a caller-supplied transport and `get_time` tool.
- [`structured-output/`](structured-output/): JSON Schema validation with a
  deterministic valid/invalid check.
- [`mcp/`](mcp/): caller-owned in-process transport with the MCP client.
- [`service/`](service/): transport-neutral request handler with health,
  principal, and run cases.
- [`provider-fallback/`](provider-fallback/): fallback model after a primary
  failure, with a deterministic check.
- [`event-sink/`](event-sink/): lifecycle and tool events through sink
  composition and filtering.
- [`streaming/`](streaming/): delta reconstruction with a deterministic check.
- [`checkpoint/`](checkpoint/): application-owned checkpoint storage with
  allowlisted payload encoding.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history save,
  reload, and continue.
- [`retry/`](retry/): retry transient failures with bounded attempts and a
  deterministic check.
- [`identity-policy/`](identity-policy/): bind a trusted principal to policy
  and reject effects before execution.
- [`hitl/`](hitl/): approve a write, then edit it to a denied value and verify
  that reauthorization stops the effect.

The examples use the repository OCaml Core through
`#use "praxo_core_bundle.ml"`, resolved from `language/ocaml/src` by `-I`, and
run with `ocaml -I language/ocaml/src <file>`. They are deterministic and do
not require network access, credentials, or a model service, except for the
transport-seam `live-model` example.
