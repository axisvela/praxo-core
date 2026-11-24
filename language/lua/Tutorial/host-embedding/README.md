# Lua Host Embedding

A native Lua Core tutorial for embedding an Agent inside an existing host. The
host receives a device event, exposes two fixed callbacks, and receives a
review-only report. It does not send a device command, open a socket or require a
model endpoint.

## Why this language and runtime?

- **Selection basis:** Lua is designed for embedding, so host applications can expose
  scoped device or application state without a separate Agent service.
- **Demonstrated fit:** Host-callback-shaped tools and a review-only action run in a
  Lua process; no real device or host socket is connected.
- **Choose when:** Learning the callback boundary before embedding in a real host.
- **Do not choose when:** Seeking a standalone service or device control. Compare the
  host's native extension API and its security model first.
- **Evidence limit:** Core integration fixture only; no real host, device command,
  socket, memory measurement or embedding guarantee.

## Run

From the repository root:

```bash
lua language/lua/Tutorial/host-embedding/app.lua
lua language/lua/Tutorial/host-embedding/app.lua --test
```

The default output contains the fixed `device-100` snapshot, a `draft_only`
`notify_operator` draft, and an empty `device_writes` list. The test covers
success, an out-of-scope device denied before callbacks, and simulated telemetry
failure.

## Embedding Shape

The host owns the event loop and supplies deterministic callbacks:

```text
host event -> Lua Core Agent -> read_device callback
                              -> draft_action callback
                              -> report to the host
```

`read_device` is read-only. `draft_action` returns a `draft_only`,
`review_required` record. The model chooses only from the registered tools; the
host and policy fix the device and action scope. There is no `os.execute`, HTTP
transport or device protocol in the tutorial.

## Boundaries

- The device is synthetic and fixed; no real telemetry, MQTT, serial, GPIO,
  firmware update or device command exists.
- The draft is for operator review, not a command, safety decision or
  real-time control action.
- The host owns identity, approvals, persistence, audit, isolation and effect
  reconciliation.
- No live model, public endpoint or independent consumer evidence is claimed.
- Lua is embedded in a host; this is not a standalone hosted agent service.
