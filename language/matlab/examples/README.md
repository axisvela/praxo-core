# MATLAB Examples

MATLAB and Octave share the Core implementation in
`language/matlab-octave-core/+praxo`. Run these examples with both paths on the
interpreter search path. There is no separate Octave example root; the Octave
package reuses this directory.

- [`consumer/`](consumer/): deterministic allow/deny governed tool path with an
  explicit tool scope and policy.
- [`live-model/`](live-model/): OpenAI-compatible adapter with a `get_time` tool.
- [`identity-policy/`](identity-policy/): trusted principal binding and
  pre-effect denial.
- [`checkpoint/`](checkpoint/): checkpoint allowlist round trip.
- [`hitl/`](hitl/): approve, edit, reject, and respond interrupt decisions.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history save and restore.
- [`event-sink/`](event-sink/): lifecycle and tool events.
- [`provider-fallback/`](provider-fallback/): fallback after a primary model
  failure.
- [`retry/`](retry/): bounded retry for transient model failures.
- [`streaming/`](streaming/): incremental chunk assembly.
- [`structured-output/`](structured-output/): JSON Schema validation.
- [`mcp/`](mcp/): caller-owned MCP-shaped transport.
- [`service/`](service/): embedded service boundary.

Example:

```bash
octave-cli --path language/matlab-octave-core \
  --path language/matlab/examples/checkpoint --eval checkpoint_example
```
