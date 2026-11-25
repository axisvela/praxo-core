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
- **Evidence limit:** Fixture adapter and deterministic model for tests. The live
  path is wired but not recorded because the local TLS backend build is blocked.

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
`"live"` rather than `"deterministic"`. The live model uses the Core
OpenAI-compatible adapter. This local workstation cannot build the TLS backend
(`ring` requires native C headers), so no live run is recorded in this revision.

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

The live path reads `PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY`. It uses
the Core `http-ureq` feature. On this workstation the Rust TLS backend build is
blocked by missing native C headers for `ring`, so the live run is not recorded.
Do not claim live Rust reasoning until a TLS-capable environment records the
model-selected tools, diagnosis/rationale, and `agent_trace`.

## Boundaries

- No real MQTT, OPC UA, socket, device SDK, or device write.
- No durable incident store, exactly-once effect, or production identity.
- Fixture gateway and deterministic model are teaching components.
- The module uses a local path dependency; it is not crate-registry evidence.
- Local deterministic tests are recorded; live reasoning is blocked in this
  environment.
