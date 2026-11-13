# MCP

This example uses published crates.io `praxo-core@0.6.0` with an in-process
`McpHttpTransport`. It needs no server process and no network endpoint.

The client performs the MCP initialize handshake, lists tools, calls `add`, and
registers the tools into a `Registry` in the real integration. The transport
here answers JSON-RPC requests directly so the example is deterministic.

## Run the deterministic check

```bash
cargo run
```

Expected output:

```text
mcp test: ok
```

## Wiring a real server

Replace `InProcessTransport` with a real `McpHttpTransport`, or use
`McpClient::connect` with `McpServerConfig` for stdio servers. Keep MCP tool
discovery and registration at the application boundary; Core does not ship a
hosted MCP runtime.
