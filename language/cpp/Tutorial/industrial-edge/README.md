# C++ industrial edge maintenance

A scoped industrial tutorial over the native MIT C++ Core. It reads one fixed
`edge-100` snapshot through an application-owned `DeviceAdapter` interface and
drafts an operator maintenance action. The adapter is an in-process fixture.
This tutorial does not implement a real fieldbus, OPC UA, socket, device SDK,
live model or device write.

## Why this language and runtime?

- **Selection basis:** An existing C++ industrial application can embed Core beside
  its device SDK rather than adding a separate Agent service.
- **Demonstrated fit:** An application-owned interface, exceptions and deterministic
  tools exercise the Core over an in-process snapshot.
- **Choose when:** Adding a governed review seam to an already maintained C++ host.
- **Do not choose when:** Seeking fieldbus/OPC UA integration or real-time guarantees.
  Compare the existing device SDK path and deterministic rules first.
- **Evidence limit:** Core integration only; no fieldbus, socket, SDK, timing
  measurement, safety certification or production device access.

Build the static library and the tutorial from the repository root:

```bash
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build --target praxo-cpp-industrial-edge-tutorial
./language/cpp/build/praxo-cpp-industrial-edge-tutorial --test
./language/cpp/build/praxo-cpp-industrial-edge-tutorial --device edge-200
./language/cpp/build/praxo-cpp-industrial-edge-tutorial --simulate-failure
```

Expected test output:

```text
success: edge-100 health=degraded action=schedule_maintenance status=draft_only writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: DEVICE_READ_FAILED reads=1
```

`edge-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, raises `DEVICE_READ_FAILED`, and exits `1`.

## Path

1. `read_device` calls the `DeviceAdapter`; the fixture returns
   `health=degraded`, firmware `edge-2.4.1`, temperature `71`, vibration `4.2`,
   pressure `6.1` and link `fieldbus` for `edge-100`.
2. `draft_maintenance` returns `status=draft_only`, `review_required=true` and
   `device_writes=0` for `schedule_maintenance`.
3. The deterministic model packages the two tool results into a JSON report.
   The application remains the owner of approval, effect reconciliation and any
   later device write.

A failing adapter raises `praxo::PraxoError("DEVICE_READ_FAILED", ...)` from the
tool, so the run fails closed after one read with zero maintenance drafts.

## Scope

This is source and local fixture evidence. It does not establish a real
industrial runtime, protocol transport, production telemetry, a live provider,
public hosting or independent adoption. A real adapter belongs in the
application and must supply its own connection, timeout, authentication and
reconciliation contracts. Tool names and report fields are tutorial-local and
are not Core or wire API.
