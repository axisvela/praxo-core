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

The canonical per-language list is the [adapter status](../languages/adapter-status.md#mcp)
table. The Go reference (`adapters/mcp`) implements stdio and Streamable HTTP
2025-03-26. Streamable HTTP clients also exist for Python, TypeScript, C#, Java,
Rust (caller-supplied seam), Ruby, PHP, Elixir, Erlang, Dart, Perl, D,
Delphi/Free Pascal, Objective-C, and Zig; Swift defines an HTTP transport but
its full local build verification is blocked by the toolchain. R, Lua, Haskell,
Julia, MATLAB, GNU Octave, Nim, OCaml, and V expose caller-supplied transport
seams; PowerShell wraps the C# client and transports. The Java implementation
compiles, but its local runtime verification remains pending.

C, C++, Fortran, and COBOL do not have an in-tree MCP client. C/C++/Fortran
already provide HTTP transport seams that can carry JSON-RPC; COBOL needs a
caller-supplied transport callback. These are unimplemented, not documented
language limitations.

All listed clients use deterministic fake servers or transport fixtures. No
live MCP service, remote transport, or production authentication evidence is
claimed. Missing clients in other
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
