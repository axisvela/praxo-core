# Rust IoT gateway diagnosis

A scoped edge tutorial over the published MIT `praxo-core` Rust crate. It reads
one fixed gateway snapshot through an application-owned `GatewayAdapter` trait,
asks a deterministic model for a diagnosis, and drafts an operator review action.
The gateway adapter is an in-process fixture. This tutorial does not implement
MQTT, OPC UA, a socket, a real device SDK, a live model, or a device write.

## Why this language and runtime?

- **Selection basis:** An edge gateway already written in Rust can embed the native
  Core without shipping a second runtime. No deployed gateway is verified here.
- **Demonstrated fit:** The published crate, an application-owned trait and
  deterministic tools run as an in-process fixture.
- **Choose when:** Evaluating the Core seam in an existing Rust edge component.
- **Do not choose when:** Seeking protocol or device support. Compare direct MQTT,
  OPC UA or device-SDK code and measure actual binary and deployment constraints.
- **Evidence limit:** Core integration only; no socket, real device, network
  transport, binary-size measurement or fault-tolerance claim.

## Run

```bash
cargo run --quiet -- --test
cargo run --quiet -- --device device-100
cargo run --quiet -- --device device-200
cargo run --quiet -- --simulate-failure
```

Expected test output:

```text
success: device-100 link=degraded action=open_ticket status=draft_only writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: GATEWAY_READ_FAILED reads=1
```

`device-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, fails with `GATEWAY_READ_FAILED`, and exits `1`.

## Path

1. `read_gateway` calls the `GatewayAdapter`; the fixture returns temperature
   `82`, pressure `118.5`, link `degraded` and firmware `1.4.2` for `device-100`.
2. `draft_action` returns `status=draft_only`, `review_required=true` and
   `device_writes=0` for `open_ticket`.
3. The deterministic model returns a JSON report. The application remains the
   owner of identity, approval, effect reconciliation and any later device write.

## Scope

This is source and local fixture evidence. It does not establish a real gateway
runtime, protocol transport, production telemetry, a live provider, public
hosting or independent adoption. A real adapter belongs in the application and
must supply its own connection, timeout, authentication and reconciliation
contracts. Tool names and report fields are tutorial-local and are not Core or
wire API.
