# MCP Resources and Prompts Demo

This example connects an in-memory MCP client to an in-memory server and uses
the optional `adapters/mcp` helpers to list and read resources and prompts. It
does not start a subprocess or open a network connection.

It is a separate Go module so the core framework and `examples/ecosystem` do not
depend on the MCP SDK.

## Run

```bash
cd examples/ecosystem/mcp
GOWORK=off go run .
```

## Test

```bash
cd examples/ecosystem/mcp
GOWORK=off go test ./...
```

The demo calls `ListResources`, `ReadResource`, `ListPrompts`, and `GetPrompt`
against a server that exposes one `demo:status` resource and one `summarize`
prompt.
