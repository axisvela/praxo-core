# Rust AI Edge Gateway Agent (AI-native reference application)

A Rust edge CLI where the agent drives the primary gateway-diagnosis workflow: an
operator submits an incident intent, the agent reads application-owned gateway
telemetry, diagnoses the suspect condition, and drafts a review-only remediation.
The agent never writes to the device.

This is the AI-native Rust reference application. There is no traditional
application precursor.

## Why this language and runtime?

- **Selection basis:** Rust is common for gateways, constrained edge services, and
  host components. A native binary can embed the Core without a second runtime.
- **Demonstrated fit:** A CLI, an application-owned `GatewayAdapter`, governed
  tools, and a model trace exercise the Core seam in an edge-shaped host.
- **Choose when:** Adding a bounded diagnosis/review action to an existing Rust
  edge component that already owns transport, identity, and device effects.
- **Do not choose when:** Direct MQTT, OPC UA, or a device SDK already solves the
  task, or when a simpler deterministic runbook is sufficient.
- **Evidence limit:** Fixture adapter and deterministic model for tests. A hosted
  DeepSeek live run is recorded through an application-owned `curl` transport; it
  is not a real MQTT, OPC UA, or device-write integration.

## AI-native workflow

1. Run the CLI with a tenant, device id, and incident intent.
2. The agent reads telemetry through the `GatewayAdapter`.
3. The model writes a diagnosis and rationale and drafts a review-only action.
4. The report returns `executions=0`.
5. An operator approves and performs any device action outside the agent.

If the model is removed, the primary gateway workflow disappears.

## Where is the LLM reasoning?

The deterministic tests use a scripted model. They verify the harness, policy,
failure paths, and trace shape, not LLM reasoning.

In the live path, the model chooses tools/arguments and writes the diagnosis and
rationale. `agent_trace` records tool calls and model output, and `model` is
`"live"` rather than `"deterministic"`. A local hosted DeepSeek `deepseek-flash`
run recorded `model=live`, a `read_gateway` -> `draft_action` sequence, a
model-written diagnosis/rationale, and `executions=0`.

The live model uses an application-owned `curl` transport rather than the Core
`http-ureq` feature. That avoids the local `ring`/native-header build blocker; the
transport is plumbing, not model evidence.

## Host integration

| Boundary | Where |
| --- | --- |
| CLI entry | `src/main.rs` |
| Gateway adapter | `src/ops.rs` (`GatewayAdapter`, `FixtureGateway`) |
| Tools and policy | `src/ops.rs` |
| Trace | `src/ops.rs` (`TracingModel`) |
| Tests | `src/ops.rs` (`#[cfg(test)]`) |

Identity, gateway transport, approvals, and effect reconciliation remain
application-owned.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `read_gateway` | Read-only telemetry | Device must be `device-100` |
| `draft_action` | Saves a model-written review-only remediation | `review_remediation` plus diagnosis/rationale |
| `execute_remediation` | Would execute remediation | Always denied in the agent path |

A `Remediate now` or `Execute remediation` intent is denied before telemetry read,
drafting, or execution.

## Build and test

The module uses a local path dependency to the Rust reference source. It does not
install a published crate.

```bash
cd language/rust/application
cargo test --offline
```

Expected: six tests pass, covering the review-only package, direct-execution
denial, tenant and device scope, gateway failure, and invalid model output.

## Run

```bash
cargo run --offline -- --device device-100 \
  --intent "Investigate the edge gateway telemetry and draft a review-only remediation."
```

Direct remediation:

```bash
cargo run --offline -- --device device-100 --intent "Remediate now for device-100."
```

Expected: exit code 2 with `AGENT_POLICY_DENIED` and zero effects.

Simulated gateway failure:

```bash
cargo run --offline -- --device device-100 --simulate-failure
```

Expected: exit code 1 with `TOOL_ERROR` after one read and no draft.

## Live model

The live path reads `PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY`. It
uses an application transport that calls `curl` with the JSON request and parses
the OpenAI-compatible response. On Windows the transport adds
`--ssl-no-revoke`; the local run also used `HTTPS_PROXY`.

```bash
export PRAXO_BASE_URL=https://api.deepseek.com
export PRAXO_MODEL=deepseek-flash
export PRAXO_API_KEY=...
cargo run --offline -- --device device-100 \
  --intent "Investigate the edge gateway telemetry and draft a review-only remediation."
```

The recorded report has `model=live`, `agent_trace` with `read_gateway` then
`draft_action`, a model-written diagnosis/rationale, and `executions=0`.

## Boundaries

- No real MQTT, OPC UA, socket, device SDK, or device write.
- No durable incident store, exactly-once effect, or production identity.
- Fixture gateway and deterministic model are teaching components.
- The module uses a local path dependency; it is not crate-registry evidence.
- Deterministic tests and a hosted live run are recorded; no real edge transport,
  device write, production identity, or production deployment is claimed.
