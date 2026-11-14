# MCP

This example uses published Maven `com.axisvela:praxo-core:0.7.0` with an
in-process `McpTransport`. It needs no server process and no network endpoint.

The client performs the MCP initialize handshake, lists tools, calls `add`, and
registers the tools into a `Registry`. The transport answers JSON-RPC requests
directly so the example is deterministic.

## Run the deterministic check

```bash
mvn -q compile exec:java
```

Expected output:

```text
Java MCP example passed
```

## Wiring a real server

Replace `InProcessTransport` with `StdioMcpTransport` or an HTTP transport. Keep
MCP tool discovery and registration at the application boundary; Core does not
ship a hosted MCP runtime.
