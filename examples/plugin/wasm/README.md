# WASM Plugin Host Example

A minimal WASM host smoke test: load a module, start it, perform the health
round-trip, and stop it.

```bash
go run ./examples/plugin/wasm
```

The included `echo.wasm` is a tiny host-ABI fixture used by the framework tests.
It acknowledges requests but does not echo arbitrary payloads. A real WASM tool
plugin must export `memory`, `alloc`, and `prax_request`, and import
`env.prax_respond`; see
[plugin authoring guide](../../../docs/guides/plugins.md).

## Test

```bash
go test ./examples/plugin/wasm
```
