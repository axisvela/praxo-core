# C constrained host diagnostic component

A scoped device tutorial over the native MIT C Core. It reads one fixed
`device-100` diagnostic snapshot through an application-owned `PxDeviceAdapter`
function pointer and drafts an operator review action. The adapter is an
in-process fixture. This tutorial does not implement a real serial bus, socket,
device SDK, live model or device write.

Build the static library and the tutorial from the repository root:

```bash
cmake -S language/c -B language/c/build
cmake --build language/c/build --target praxo-c-device-diagnostics-tutorial
./language/c/build/praxo-c-device-diagnostics-tutorial --test
./language/c/build/praxo-c-device-diagnostics-tutorial --device device-200
./language/c/build/praxo-c-device-diagnostics-tutorial --simulate-failure
```

Expected test output:

```text
success: device-100 health=degraded action=notify_operator status=draft_only writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: DEVICE_READ_FAILED reads=1
```

`device-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `DEVICE_READ_FAILED`, and exits `1`.

## Path

1. `read_device` calls the `PxDeviceAdapter`; the fixture returns
   `health=degraded`, uptime `86400`, disk `91`, memory `78` and link
   `serial-bus` for `device-100`.
2. `draft_action` returns `status=draft_only`, `review_required=true` and
   `device_writes=0` for `notify_operator`.
3. The deterministic model packages the two tool results into a JSON report.
   The application remains the owner of approval, effect reconciliation and any
   later device write.

## Scope

This is source and local fixture evidence. It does not establish a real device
runtime, protocol transport, production telemetry, a live provider, public
hosting or independent adoption. A real adapter belongs in the application and
must supply its own connection, timeout, authentication and reconciliation
contracts. Tool names and report fields are tutorial-local and are not Core or
wire API.
