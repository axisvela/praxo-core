# MCP Tool Gateway

`adapters/mcp` connects an MCP client session to `tool.Gateway`, so MCP tools
can be registered in a PRAXO-CORE `tool.Registry` and used by the agent loop.

This is an optional module. The core framework does not depend on the MCP SDK.

```bash
go get github.com/axisvela/praxo-core/adapters/mcp@v0.3.0
```

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

## Resources and Prompts

For model-facing registration, use `NewTools(ctx, session)` and register the
returned `tool.Tool` values. This unreleased entry point preserves MCP input
schemas through `tool.SpecProvider`. The generic `tool.NewGatewayTools` path
retains names and descriptions but cannot carry MCP input schemas.

Tool discovery follows pagination and rejects repeated cursors and duplicate
names. Resources and prompts retain their existing separate listing helpers.

The module also exposes MCP resources and prompts:

```go
resources, err := mcpx.ListResources(ctx, session)
contents, err := mcpx.ReadResource(ctx, session, "embedded:info")

prompts, err := mcpx.ListPrompts(ctx, session)
messages, err := mcpx.GetPrompt(ctx, session, "greet", map[string]string{
    "name": "Ada",
})
```

These helpers follow pagination cursors and return plain Go values. They are
module-level conveniences, not part of the core agent interfaces.

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
