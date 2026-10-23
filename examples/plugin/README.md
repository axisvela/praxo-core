# Process Plugin Example

This example shows a minimal runtime plugin process and a host that invokes it
through `pkg/plugin/host/process`.

## Build

```bash
go build -o echo-plugin ./examples/plugin/echo-plugin
```

On Windows:

```powershell
go build -o echo-plugin.exe ./examples/plugin/echo-plugin
```

## Run

```bash
go run ./examples/plugin/host -plugin ./echo-plugin
```

On Windows:

```powershell
go run ./examples/plugin/host -plugin ./echo-plugin.exe
```

The host starts the plugin, performs the `host.control/health` handshake,
invokes `tool.provider/invoke`, prints the echoed payload, and stops the plugin.

## Protocol

The plugin speaks JSON-Lines over stdio and validates the
`PRAXOVELA_PLUGIN_TOKEN` environment variable on every request. It handles:

- `host.control/health`
- `host.control/cancel`
- `host.control/shutdown`
- `tool.provider/invoke`

Unknown methods return `NOT_FOUND`; a bad token returns `CAPABILITY_DENIED`.

The example sets `RequireLimits: false` for portability. Production hosts should
set `RequireLimits` and `RequireEvidence` as described in
[docs/10-plugin-authoring.md](../../docs/10-plugin-authoring.md).

## Test

```bash
go test ./examples/plugin/...
```
