# MCP Client Boundary

This is the minimal MCP client boundary for a Core implementation. The Go
reference uses `adapters/mcp` with the official Go SDK. Other implementations
may use a native JSON-RPC client or an MCP client library with compatible
licensing.

## Transport

- stdio JSON-RPC 2.0, one JSON object per line.
- Requests carry a unique `id`; responses echo it.
- Notifications carry no `id`.
- The client owns the child process lifecycle and must close it on success,
  error, and cancellation.

## Handshake

1. Send `initialize` with `protocolVersion`, `capabilities: {}`, and
   `clientInfo: {name, version}`.
2. Require a successful result and a non-empty negotiated protocol version.
3. Send `notifications/initialized`.
4. On failure, run any negotiated shutdown/exit sequence and terminate the child.

## Tools

- `tools/list` accepts an optional `cursor`.
- Follow `nextCursor` until it is absent.
- Reject a repeated cursor and duplicate tool names.
- Preserve `inputSchema` as the model-facing parameter schema.
- `tools/call` sends `{name, arguments}`.
- Return structured content when present; otherwise return text content as a
  string or an ordered list of text blocks.
- A tool failure is an error result, not an empty success.

## Timeouts and Cancellation

- Bound initialize, list, and call operations with a caller-configurable
  timeout.
- Send `notifications/cancelled` when the caller cancels an in-flight request.
- Do not report a local cancellation as proof that remote work stopped.

## Baseline Status

Native stdio clients currently cover Go (`adapters/mcp`), Python
(`praxo.adapters.mcp`), and TypeScript (`src/adapters/mcp.ts`). The Python and
TypeScript clients are deterministic fake-server pilots, not live-service or
remote-transport evidence. Other implementations remain unclaimed.

## Security and Scope

- MCP authentication belongs to the client session or transport.
- The boundary does not imply a hosted MCP service, schema promotion, sandbox
  isolation, or production authentication.
- Tool output is untrusted content; policy and tool authorization still apply.
- Do not rewrite tool-call markup or bypass the Core policy seam.

## Testing

Use a fake MCP server over stdio. Required assertions: initialize handshake,
pagination, repeated-cursor rejection, duplicate-name rejection, successful
call, error call, and process cleanup. A live MCP server is integration
evidence, not the only test.
