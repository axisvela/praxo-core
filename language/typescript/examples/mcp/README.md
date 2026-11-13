# MCP Stdio Client

This example uses published npm `@axisvela/praxo-core@0.5.0` to connect to a
minimal stdio MCP server, list tools, register them in a Core registry, and call
one tool.

## Run

```bash
npm install
npm start
```

Expected output:

```text
tools=add,echo; sum=5
```

## Test

The server is local and deterministic; no external MCP service is required.

```bash
npm test
```

MCP tool output remains untrusted. Policy still authorizes every tool call when
these tools are registered with an Agent. This client example does not provide
remote authentication, schema promotion, or a hosted MCP service.
