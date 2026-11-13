# MCP Client by Language

This tutorial connects a published Core package to a local MCP server, lists
tools, registers them in a Core registry, and calls one tool.

Runnable examples:

- [Python stdio](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/mcp)
- [TypeScript stdio](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/mcp)
- [C# in-process transport](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/mcp)

Each example uses a deterministic local server. No external MCP service is
required.

## Python

```bash
cd language/python/examples/mcp
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python client.py
.venv/bin/python -m unittest test_client.py -v
```

Expected output:

```text
tools=add,echo; sum=5
```

## TypeScript

```bash
cd language/typescript/examples/mcp
npm install
npm start
npm test
```

## C#

```bash
cd language/csharp/examples/mcp
dotnet run
dotnet run -- --test
```

## Flow

1. Start or connect to the MCP transport.
2. Initialize the session.
3. List tools, following pagination and rejecting duplicate names.
4. Register selected tools in a Core registry.
5. Authorize every tool call before it reaches the server.
6. Call the tool and treat the result as untrusted input.

The C# example uses an in-process transport. For a real stdio server, use
`McpServerOptions` and `new McpClient(options)`; the client flow is the same.

## Boundaries

- MCP is a tool session, not a model provider.
- Authentication belongs to the transport or server session.
- Tool output is untrusted content.
- Local cancellation does not prove remote work stopped.
- This example does not provide a hosted MCP service, schema promotion, or
  production isolation.

## Related

- [Provider and MCP walkthrough](provider-walkthrough.md)
- [Examples](../getting-started/examples.md)
- [MCP client reference](../reference/mcp-client.md)
- [Adapter status](../languages/adapter-status.md#mcp)
- [Application integration checklist](application-integration-checklist.md)
