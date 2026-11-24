# Zig small gateway health check

A scoped edge tutorial over the native MIT Zig Core. It reads one fixed
`gateway-100` health snapshot through an application-owned `GatewayAdapter`
function table and drafts an operator review action. The adapter is an in-process
fixture. This tutorial does not implement MQTT, OPC UA, a socket, a real device
SDK, a live model or a device write.

## Why this language and runtime?

- **Selection basis:** A constrained Zig deployment may benefit from a native Core
  with an explicit adapter function table; no deployed gateway is verified here.
- **Demonstrated fit:** Native callback tools and policy checks run over a fixed
  in-process snapshot. No transport, device SDK or allocation limit is exercised.
- **Choose when:** Learning the Core seam for an existing Zig edge component.
- **Do not choose when:** Seeking a proven small binary, zero-allocation runtime or
  protocol integration. Compare direct Zig code and measure real deployment limits.
- **Evidence limit:** Core integration only; no measured binary size, memory ceiling,
  socket, device write or platform guarantee.

Requires Zig `0.17.0`. Run from the repository root:

```bash
mkdir -p build
zig build-exe --dep praxo -Mroot=language/zig/Tutorial/gateway-health/main.zig -Mpraxo=language/zig/src/praxo.zig -femit-bin=build/praxo-zig-gateway
./build/praxo-zig-gateway --test
./build/praxo-zig-gateway --device gateway-200
./build/praxo-zig-gateway --simulate-failure
```

Expected test output:

```text
success: gateway-100 health=degraded action=restart_telemetry status=draft_only writes=0 reads=1
deny: PolicyError reads=0
failure: GatewayReadFailed reads=1
```

`gateway-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, fails with `GatewayReadFailed`, and exits `1`.

## Path

1. `read_gateway` calls the `GatewayAdapter`; the fixture returns `health=degraded`,
   uptime `86400`, disk `91`, memory `78` and link `mqtt-bridge` for `gateway-100`.
2. `draft_action` returns `status=draft_only`, `review_required=true` and
   `device_writes=0` for `restart_telemetry`.
3. The deterministic model packages the two tool results into a JSON report. The
   application remains the owner of approval, effect reconciliation and any later
   device write.

## Scope

This is source and local fixture evidence. It does not establish a real gateway
runtime, protocol transport, production telemetry, a live provider, public
hosting or independent adoption. A real adapter belongs in the application and
must supply its own connection, timeout, authentication and reconciliation
contracts. Tool names and report fields are tutorial-local and are not Core or
wire API.
