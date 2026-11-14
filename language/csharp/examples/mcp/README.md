# MCP Client

This example uses published NuGet `Praxo.Core==0.8.0` with an in-process MCP
transport. It exercises the same `initialize`, `tools/list`, and `tools/call`
flow as a stdio session without requiring another runtime.

## Run

```bash
dotnet run
```

Expected output:

```text
tools=add,echo; sum=5
```

## Deterministic check

```bash
dotnet run -- --test
```

The transport is local and deterministic. For a real stdio server, use
`McpServerOptions` and `new McpClient(options)`; the rest of the client flow is
the same.

MCP tool output remains untrusted. Policy still authorizes every tool call when
these tools are registered with an Agent. This example does not provide remote
authentication, schema promotion, or a hosted MCP service.
