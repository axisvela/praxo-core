# MCP Client Boundary

This is the minimal MCP client boundary for a Core implementation. The Go
reference uses `adapters/mcp` with the official Go SDK. Other implementations
may use a native JSON-RPC client or an MCP client library with compatible
licensing.

## Transports

### stdio (2024-11-05)

- stdio JSON-RPC 2.0, one JSON object per line.
- Requests carry a unique `id`; responses echo it.
- Notifications carry no `id`.
- The client owns the child process lifecycle and must close it on success,
  error, and cancellation.

### Streamable HTTP (2025-03-26 or later)

- `POST {endpoint}` with `content-type: application/json` and
  `accept: application/json, text/event-stream`.
- A POST response may be JSON or an SSE stream; parse both.
- `initialize` returns an `Mcp-Session-Id` header. Keep it and send it on every
  later request. If the server supports termination, send `DELETE {endpoint}`.
- Send `MCP-Protocol-Version: 2025-03-26` on requests after initialization.
- `GET {endpoint}` may open an optional standalone SSE stream for
  server-initiated messages. Reconnect without replaying earlier requests.
- Remote endpoints must use HTTPS; loopback HTTP is permitted for local tests.
- Authentication is caller-supplied, for example a bearer token or OAuth.
- Abort the HTTP request on cancellation. A local abort is not proof that
  remote work stopped.

## Handshake

1. Send `initialize` with `protocolVersion`, `capabilities: {}`, and
   `clientInfo: {name, version}`.
2. Require a successful result and a non-empty negotiated protocol version.
3. Send `notifications/initialized`.
4. On failure, run any negotiated shutdown/exit sequence. For stdio, terminate
   the child; for HTTP, close the session and send `DELETE` when supported.

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

The Go reference (`adapters/mcp`) implements both transports:
`ConnectStdio`/`NewStdioGateway` over a child process, and
`ConnectStreamableHTTP`/`NewStreamableHTTPGateway` over Streamable HTTP with a
caller-supplied `*http.Client`. Python (`praxo.adapters.mcp_http`),
TypeScript (`src/adapters/mcp-http.ts`), C#
(`McpStreamableHttpTransport`), and Java (`McpStreamableHttpTransport`) also
implement Streamable HTTP 2025-03-26. Ruby, PHP, Elixir, Erlang, Dart, and Perl
add Streamable HTTP transports with JSON/SSE parsing and HTTPS enforcement. D
adds `praxo.mcp.McpClient` with stdio and `HttpMcpTransport`. Delphi / Free
Pascal adds `TPraxoMcpClient` with stdio and `TPraxoHttpMcpTransport`.
Objective-C adds `PXRMcpClient` with stdio and `PXRHttpMcpTransport`. Zig adds
`mcp.Client` with stdio and a curl-backed `HttpTransport`. Swift has
`McpClient`, `StdioMcpTransport`, and `HttpMcpTransport`; the source typechecks
under the documented Windows SDK/MSVC workaround, but a full local build/test is
still blocked by the toolchain, so macOS CI remains the full `swift test` gate.
Rust adds
`McpClient::connect_http` over a caller-supplied `McpHttpTransport` seam. C#,
Rust, Ruby, PHP, Dart, D, Delphi/Free Pascal, Objective-C, and Zig have local
transport-fixture tests; Elixir and Erlang have integration tests for the
transport seam but not a live HTTP fixture; the Java implementation compiles,
but its local runtime verification is pending.

Native stdio clients currently cover Python (`praxo.adapters.mcp`), TypeScript
(`src/adapters/mcp.ts`), Java (`adapters.McpClient`), Rust (`mcp::McpClient`),
C# (`Praxo.Core.Adapters.McpClient`), Elixir (`Praxo.Mcp`), Erlang
(`praxo_mcp`), Ruby (`Praxo::Adapters::MCPClient`), PHP
(`Praxo\Core\Adapters\MCPClient`), Dart (`McpClient`), and Perl
(`Praxo::Adapters::MCP`). R (`mcp_client`) and Lua (`praxo.adapters.mcp`) use
caller-supplied transport seams. The remaining stdio-only implementations do
not implement Streamable HTTP yet.

These are deterministic fake-server or transport-fixture implementations, not
live-service or remote-transport evidence. Missing clients in other
implementations are not yet implemented, not a documented language limitation:
the same JSON-RPC state machine can run over a native stdio child process, a
Streamable HTTP client, or a caller-supplied request/response transport where
the runtime provides one.

## Security and Scope

- MCP authentication belongs to the client session or transport.
- The boundary does not imply a hosted MCP service, schema promotion, sandbox
  isolation, or production authentication.
- Tool output is untrusted content; policy and tool authorization still apply.
- Do not rewrite tool-call markup or bypass the Core policy seam.

## Testing

Use a fake MCP server over stdio and a loopback TLS Streamable HTTP fixture.
Required assertions: initialize handshake, pagination, repeated-cursor
rejection, duplicate-name rejection, successful call, error call, session
cleanup, and HTTPS enforcement. A live MCP server is integration evidence, not
the only test.
