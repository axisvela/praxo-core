# Plugin Authoring

This guide covers the framework-side runtime plugin contract. Signature trust,
materialization, SBOM/evidence, and update policy are product-owned (PRAXOVELA).

A runnable minimal process plugin and host live in
[`examples/plugin`](https://github.com/axisvela/praxo-core/tree/main/examples/plugin).

## Manifest v1

A plugin ships a strict JSON manifest. Unknown fields and trailing data are
rejected.

```json
{
  "schemaVersion": 1,
  "id": "com.example.search",
  "version": "1.0.0",
  "kind": "tool.provider.v1",
  "entrypoint": { "type": "process", "command": "./bin/search" },
  "protocol": "jsonrpc-2",
  "capabilities": ["tool.invoke"],
  "permissions": {
    "filesystem": [{ "path": "/workspace", "mode": "read" }],
    "network": [{ "host": "api.example.com", "port": 443 }],
    "env": ["SEARCH_API_KEY"]
  },
  "limits": { "memoryMB": 256, "cpuMillis": 2000, "timeoutMs": 30000, "maxInflight": 8 },
  "isolation": "process",
  "health": { "method": "health", "intervalMs": 15000 },
  "signature": { "algorithm": "ed25519", "keyId": "example-release-1" },
  "sbom": "sbom.spdx.json"
}
```

- `kind` is one of `tool|model|policy|memory|sandbox`.provider.v1.
- `entrypoint.type` and `isolation` are `process`, `wasm`, or `container` and
  must match.
- `entrypoint.command` is required for `process`; `entrypoint.module` for
  `wasm`; `entrypoint.image` for `container`.
- `permissions` is deny-by-default. Filesystem modes are `read`, `write`, or
  `readwrite`.
- `signature` and `sbom` are mandatory under the signed trust profile. The
  unsigned profile is an explicit local-development opt-in.

Parse and validate with:

```go
m, err := plugin.ParseManifest(raw)
if err != nil { /* reject */ }
if err := m.ValidateTrust(plugin.TrustSigned); err != nil { /* reject */ }
```

## Process host

The process host speaks JSON-Lines over the child's stdio. Each request is one
JSON object per line:

```json
{
  "id": "req-1",
  "version": 1,
  "plugin_id": "com.example.search",
  "service": "tool.provider",
  "method": "invoke",
  "token": "<per-process token>",
  "payload": "<opaque contract bytes>"
}
```

The plugin replies with:

```json
{
  "id": "req-1",
  "version": 1,
  "ok": true,
  "payload": "<opaque contract bytes>"
}
```

Rules:

- Validate `token` on every request. The host provisions it through the
  `PRAXOVELA_PLUGIN_TOKEN` environment variable by default (override with
  `process.Config.TokenEnvVar`); it is never passed in argv.
- Answer `health` during start.
- Abandon in-flight work on `cancel`; exit cleanly after `shutdown`.
- Map failures to `CAPABILITY_DENIED`, `NOT_ACTIVE`, `NOT_FOUND`,
  `INVALID_REQUEST`, `TIMEOUT`, or `INTERNAL`.
- Do not write protocol frames to stderr; stderr is captured and bounded.

Host-side configuration (`process.Config`) includes `PluginID`, `Provider`,
`Sink`, `RequireEvidence`, `Path`, `Args`, `Dir`, `Env`, `Token`, `TokenEnvVar`,
timeouts, frame bound, `Limits`, and `RequireLimits`. Production callers should
set `RequireLimits` and `RequireEvidence`.

## WASM host

A WASM guest must export:

- `memory`
- `alloc(len i32) i32`
- `prax_request(ptr i32, len i32)`

and import `env.prax_respond(ptr i32, len i32)`. Each `prax_request` must deliver
exactly one response frame. The host bounds linear memory with
`MaxMemoryPages` and terminates a guest when the invocation context ends. CPU
fuel is not enforced in v1.

## Conformance kit

Implement `tck.HostFactory` / `tck.HostHarness`:

```go
type HostHarness interface {
    Start(context.Context) error
    Stop(context.Context) error
    Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error)
    PluginID() string
    Contract() plugin.Contract
    Methods() tck.HostMethods
}
```

`HostMethods` names the fixture methods:

- `Echo`: return the payload unchanged.
- `Block`: wait until the context is done.
- `Denied`: return `CAPABILITY_DENIED`.
- `Timeout`: bound the blocking invocation.

Then run:

```go
if err := tck.CheckLifecycle(plugin.NewLifecycle()); err != nil { /* fail */ }
if err := tck.CheckRegistry(registry); err != nil { /* fail */ }
if err := tck.CheckHost(factory); err != nil { /* fail */ }
```

`CheckHost` covers framing, timeout, cancellation, capability denial, and the
not-active gate. Each check gets a fresh host from the factory.

## Trust boundary

Core hosts start already-verified payloads. The product must verify the
descriptor signature, SBOM, identity, ABI, and compatibility before constructing
a host. `pkg/plugin` never resolves requirements and never calls a trust store.
