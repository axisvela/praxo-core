# MCP Tool Gateway

`adapters/mcp` connects an MCP client session to `tool.Gateway`, so MCP tools
can be registered in a PRAXO-CORE `tool.Registry` and used by the agent loop.

This is an optional module. The core framework does not depend on the MCP SDK.

```go
client := mcp.NewClient(&mcp.Implementation{Name: "agent", Version: "v0.1.0"}, nil)
session, err := client.Connect(ctx, &mcp.CommandTransport{
    Command: exec.Command("my-mcp-server"),
}, nil)
if err != nil {
    return err
}
defer session.Close()

gateway, err := mcpx.NewGateway(ctx, session)
if err != nil {
    return err
}
tools := tool.NewGatewayTools(gateway)
for _, item := range tools {
    registry.Register(item)
}
```

`NewGateway` caches the tool list at construction. Call `Refresh` to reload it
after the server changes its tools. MCP authentication belongs to the client
session, so the token argument in `tool.Gateway.Execute` is ignored.

The gateway returns structured content when the MCP server provides it;
otherwise it returns text content as a string, or a `[]string` for multiple
text blocks.

## Test

```bash
cd adapters/mcp
GOWORK=off go test ./...
```

## Publishing

This module is currently developed in-tree and can be used with a local
`replace`. Tag `adapters/mcp/v<version>` to publish it for `go get`.
