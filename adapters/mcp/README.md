# MCP Tool Gateway

`adapters/mcp` connects an MCP client session to `tool.Gateway`, so MCP tools
can be registered in a PRAXO-CORE `tool.Registry` and used by the agent loop.

This is an optional module. The core framework does not depend on the MCP SDK.

```bash
go get github.com/axisvela/praxo-core/adapters/mcp@v0.3.0
```

```go
session, err := mcpx.ConnectStdio(ctx, exec.Command("my-mcp-server"), nil)
if err != nil {
    return err
}
defer session.Close()

tools, err := mcpx.NewTools(ctx, session)
if err != nil {
    return err
}
for _, item := range tools {
    registry.Register(item)
}
```

For a remote MCP server, use Streamable HTTP (2025-03-26). A nil client uses a
bounded default HTTP client; pass your own for authentication, tracing, or test
TLS trust.

```go
gateway, err := mcpx.NewStreamableHTTPGateway(ctx, "https://mcp.example.com/mcp", nil, nil)
if err != nil {
    return err
}
defer gateway.Close()
```

Remote endpoints must use HTTPS. Loopback HTTP is allowed for local tests.
`NewStdioGateway` and `NewStreamableHTTPGateway` close their session on a
construction error; `Gateway.Close` closes it on success.

`NewTools` preserves model-facing input schemas. For generic gateway consumers,
`NewGateway` caches the tool list at construction; call `Refresh` to reload it
after the server changes its tools. MCP authentication belongs to the client
session or HTTP client, so the token argument in `tool.Gateway.Execute` is
ignored.

## Resources and Prompts

For model-facing registration, use `NewTools(ctx, session)` and register the
returned `tool.Tool` values. This entry point is published in v0.3.0 and preserves MCP input
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

The current published tag is `adapters/mcp/v0.3.0`. Module releases are
independent of the core; use `adapters/mcp/v<version>` tags for `go get`.
