# Adapter Status

This page tracks native adapter coverage for Model providers, MCP tool sessions,
and Harmovela event delivery. Contract conformance and behavior coverage are
separate; an adapter is not production or provider evidence.

## Three Evidence Layers

Read adapter rows at one of three layers. Do not collapse them into one claim.

| Layer | What it proves | What it does not prove |
| --- | --- | --- |
| Contract complete | Declared vectors, parity inventory, and API snapshot pass for the language's declared scope | That an adapter exists or that a real provider/MCP/Harmovela service was exercised |
| Adapter available | An in-tree, transport-seam, inherited, or bridge adapter maps the shared contract | That the adapter was run against a live provider or external service |
| Integration verified | A recorded run used a real model endpoint, real MCP service, or Harmovela integration with a fixed version, environment, and date | Production readiness, all-provider coverage, or Go feature parity |

A language can be contract-complete without a native adapter, and can have an
adapter without integration verification. The matrix and support pages must say
which layer a claim uses.

Status words:

- `native`: an in-tree adapter for this implementation.
- `native (transport seam)`: request/response mapping is in-tree, but the caller
  supplies the HTTP transport.
- `inherited`: the implementation uses another Core runtime that provides the
  adapter.
- `bridge`: the implementation runs the Go Core through the bridge.
- `not implemented`: no adapter exists; do not claim support.

## Model (OpenAI-Compatible)

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/openaicompat` |
| Python | native | `praxo.adapters.openaicompat` |
| TypeScript | native | `src/adapters/openaicompat.ts` |
| Java | native | `adapters.OpenAICompatibleModel` |
| Rust | native | `openai_compat::OpenAICompatible` behind optional `http-ureq`; `parse_stream` always available |
| C# | native | `Praxo.Core.OpenAiCompatible` |
| Ruby | native | `Praxo::Adapters::OpenAICompatible`; `generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| PHP | native | `Praxo\Core\Adapters\OpenAICompatible`; implements `StreamingModel` and reassembles SSE content, tool calls, usage, and finish reason |
| Elixir | native | `Praxo.OpenAICompatible`; `streaming_model/1` and SSE reassembly cover content, tool calls, usage, and finish reason |
| Lua | native | `praxo.openai_compatible`; `stream` reassembles SSE content, tool calls, usage, and finish reason |
| Perl | native | `Praxo::Adapters::OpenAICompatible`; `generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| Nim | native | `praxo/adapters/openai_compatible`; SSE streaming reassembly |
| R | native | `openai_compatible` adapter; `openai_compatible_streaming_model` reassembles SSE content, tool calls, usage, and finish reason |
| Erlang | native | `praxo_openai_compatible`; `streaming_model/1` and `generate_stream/3` reassemble SSE content, tool calls, usage, and finish reason |
| Julia | native | `OpenAICompatibleModel`; `generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| V | native | `praxo.openaicompat`; verified with V 0.5.2 and `x.json2`; SSE streaming reassembly |
| Dart | native | `OpenAiCompatibleModel` with sync and async transport paths; `generateStream` reassembles SSE content, tool calls, usage, and finish reason |
| Haskell | native (transport seam) | Caller supplies `Transport`; no bundled HTTP client; SSE streaming reassembly |
| Swift | native | `OpenAICompatibleModel` with URLSession transport; SSE streaming reassembly |
| OCaml | native (transport seam) | Caller supplies `transport`; no bundled HTTP client; SSE streaming reassembly |
| Delphi / Free Pascal | native | `TPraxoOpenAIAdapter` with FPC HTTP transport; SSE streaming reassembly |
| Objective-C | native | `PXROpenAIGenerate` with injectable transport; SSE streaming reassembly |
| MATLAB | native | `praxo.openai_compatible` using `webwrite`; SSE streaming reassembly |
| GNU Octave | native | Shared `praxo.openai_compatible` implementation; SSE streaming reassembly |
| Zig | native | `openaicompat.Adapter` with `std.http`; SSE streaming reassembly |
| C | native (transport seam) | `PxOpenAICompatible`; caller supplies HTTP transport; `px_openai_generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| C++ | native (transport seam) | `OpenAICompatible`; caller supplies HTTP and streaming transports; `OpenAICompatibleStreamTransport` reassembles SSE content, tool calls, usage, and finish reason |
| Fortran | native (transport seam) | `openai_compatible`; caller supplies HTTP transport; `generate_stream` reassembles SSE content, tool calls, usage, and finish reason |
| D | native (transport seam) | `OpenAICompatibleModel`; caller may inject transport; SSE streaming reassembly |
| COBOL | native (transport seam) | `praxo-openai`; caller supplies a transport program and an optional delta program; SSE streaming reassembles content, tool calls, usage, and finish reason; the model callback lacks tool specs/history |
| PowerShell | inherited | Uses the C# Core |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |

Streaming-capable OpenAI-compatible adapters reassemble SSE content, fragmented
tool calls, usage, and `finish_reason`: Go, Python, TypeScript, Java, Rust, C#,
R, C, C++, Fortran, Erlang, COBOL, Ruby, PHP, Elixir, Lua, Dart, Perl, Julia, MATLAB, GNU Octave, Nim, V, Zig, Delphi, Swift, OCaml, Objective-C, Haskell, and D. The C, C++, Fortran, R, Erlang, and COBOL transports still return the
complete SSE body unless the caller supplies an incremental transport. All declared Core OpenAI-compatible adapters now have streaming coverage.

The baseline mapping is documented in the
[OpenAI-compatible model adapter](../reference/openai-compatible-adapter.md).
OpenAI, DeepSeek, Kimi/Moonshot, OpenRouter, Groq, and Together use this adapter
with different base URLs; the Python and TypeScript implementations expose
provider presets.

## Model (Anthropic Native)

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/anthropic` |
| Python | native | `praxo.adapters.anthropic.AnthropicModel`; SSE streaming reassembly |
| TypeScript | native | `src/adapters/anthropic.ts`; SSE streaming reassembly |
| C# | native | `Praxo.Core.AnthropicModel`; SSE streaming reassembly |
| R | native (transport seam) | `anthropic`; caller may supply `transport`; `anthropic_streaming_model` reassembles SSE |
| Elixir | native | `Praxo.Anthropic`; `streaming_model/1` reassembles Anthropic SSE |
| Java | native | `adapters.AnthropicModel`; SSE streaming reassembly |
| Rust | native (transport seam) | `adapters::anthropic`; caller supplies transport; `StreamingModel` via `send_stream` |
| Ruby | native | `Praxo::Adapters::Anthropic`; injectable transport; `generate_stream` reassembles Anthropic SSE |
| PHP | native | `Praxo\Core\Adapters\Anthropic`; implements `StreamingModel` with Anthropic SSE |
| Lua | native | `praxo.adapters.anthropic`; `stream` reassembles Anthropic SSE |
| Perl | native | `Praxo::Adapters::Anthropic`; `generate_stream` reassembles Anthropic SSE |
| Dart | native | `AnthropicModel` with sync and async transport paths; `generateStream` reassembles Anthropic SSE |
| Erlang | native | `praxo_anthropic`; `streaming_model/1` reassembles Anthropic SSE |
| D | native (transport seam) | `AnthropicModel`; caller may inject transport; SSE streaming reassembly |
| COBOL | native (transport seam) | `praxo-anthropic`; caller supplies a transport program; maps system messages, tools, tool choice, text, tool use, and usage |
| C | native (transport seam) | `PxAnthropic`; caller supplies HTTP transport; `px_anthropic_generate_stream` reassembles Anthropic SSE |
| C++ | native (transport seam) | `Anthropic`; caller supplies HTTP and streaming transports; Anthropic SSE reassembly |
| Fortran | native (transport seam) | `anthropic_compatible`; caller supplies HTTP transport; `generate_stream` reassembles Anthropic SSE |
| Julia | native | `AnthropicModel`; injectable transport; `generate_stream` reassembles Anthropic SSE |
| Nim | native | `newAnthropicCompatible`; injectable transport; `generateStream` reassembles Anthropic SSE |
| Haskell | native (transport seam) | `Praxo.Anthropic`; caller supplies transport; `generateAnthropicStream` reassembles Anthropic SSE |
| OCaml | native (transport seam) | `anthropic_model`; caller supplies transport; `anthropic_generate_stream` reassembles Anthropic SSE |
| Swift | native | `AnthropicModel` with injectable transport; `generateStream` reassembles Anthropic SSE |
| V | native (transport seam) | `anthropic_compatible`; caller supplies `ProviderTransport`; `generate_stream` reassembles Anthropic SSE |
| Zig | native | `anthropic.Adapter`; injectable transport; `generateStream` reassembles Anthropic SSE |
| MATLAB | native | `praxo.anthropic_compatible`; injectable transport; `onDelta` reassembles Anthropic SSE |
| GNU Octave | native | Shared `praxo.anthropic_compatible`; `onDelta` reassembles Anthropic SSE |
| Delphi / Free Pascal | native | `TPraxoAnthropicAdapter`; FPC HTTP transport; `GenerateStream` reassembles Anthropic SSE |
| Objective-C | native | `PXRAnthropicGenerate` with injectable transport; `PXRAnthropicGenerateStream` reassembles Anthropic SSE |
| PowerShell | inherited | Uses the C# Core |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |
| All other implementations | not implemented | Use the OpenAI-compatible adapter only for OpenAI-compatible endpoints |

Anthropic SSE streaming reassembles `message_start`, text deltas, tool-use JSON
deltas, `message_delta`, and `message_stop` for Go, Python, TypeScript, Java, Rust,
C#, R, Elixir, Ruby, PHP, Lua, Perl, Dart, Erlang, D, C++, C, Fortran, Julia, Nim, Haskell, OCaml, Swift, V, Zig, MATLAB, GNU Octave, Delphi, Objective-C, and COBOL. Other Anthropic adapters remain non-streaming.

## Model (Gemini Native)

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/gemini`; SSE streaming reassembly |
| Python | native | `praxo.adapters.gemini.GeminiModel`; SSE streaming |
| TypeScript | native | `src/adapters/gemini.ts`; SSE streaming |
| C# | native | `Praxo.Core.GeminiModel`; SSE streaming |
| R | native (transport seam) | `gemini`; caller may supply `transport`; SSE streaming |
| Elixir | native | `Praxo.Gemini`; `streaming_model/1` reassembles Gemini SSE |
| Java | native | `adapters.GeminiModel`; SSE streaming |
| Rust | native (transport seam) | `adapters::gemini`; caller supplies transport; `StreamingModel` via `send_stream` |
| Ruby | native | `Praxo::Adapters::Gemini`; injectable transport; `generate_stream` reassembles Gemini SSE |
| PHP | native | `Praxo\Core\Adapters\Gemini`; implements `StreamingModel` with Gemini SSE |
| Lua | native | `praxo.adapters.gemini`; `stream` reassembles Gemini SSE |
| Perl | native | `Praxo::Adapters::Gemini`; `generate_stream` reassembles Gemini SSE |
| Dart | native | `GeminiModel`; `generateStream` reassembles Gemini SSE |
| Erlang | native | `praxo_gemini`; `streaming_model/1` reassembles Gemini SSE |
| D | native (transport seam) | `GeminiModel`; caller may inject transport; SSE streaming |
| COBOL | native (transport seam) | `praxo-gemini`; caller supplies a transport program; maps system instructions, tools, tool choice, text, function calls, usage, and Gemini SSE streaming |
| C | native (transport seam) | `PxGemini`; caller supplies HTTP transport; `px_gemini_generate_stream` reassembles Gemini SSE |
| C++ | native (transport seam) | `Gemini`; caller supplies HTTP and streaming transports; Gemini SSE reassembly |
| Fortran | native (transport seam) | `gemini_compatible`; caller supplies HTTP transport; `generate_stream` reassembles Gemini SSE |
| Julia | native | `GeminiModel`; injectable transport; `generate_stream` reassembles Gemini SSE |
| Nim | native | `newGeminiCompatible`; injectable transport; `generateStream` reassembles Gemini SSE |
| Haskell | native (transport seam) | `Praxo.Gemini`; caller supplies transport; `generateGeminiStream` reassembles Gemini SSE |
| OCaml | native (transport seam) | `gemini_model`; caller supplies transport; `gemini_generate_stream` reassembles Gemini SSE |
| Swift | native | `GeminiModel` with injectable transport; `generateStream` reassembles Gemini SSE |
| V | native (transport seam) | `gemini_compatible`; caller supplies `ProviderTransport`; `generate_stream` reassembles Gemini SSE |
| Zig | native | `gemini.Adapter`; injectable transport; `generateStream` reassembles Gemini SSE |
| MATLAB | native | `praxo.gemini_compatible`; injectable transport; `onDelta` reassembles Gemini SSE |
| GNU Octave | native | Shared `praxo.gemini_compatible`; `onDelta` reassembles Gemini SSE |
| Delphi / Free Pascal | native | `TPraxoGeminiAdapter`; FPC HTTP transport; `GenerateStream` reassembles Gemini SSE |
| Objective-C | native | `PXRGeminiGenerate` with injectable transport; `PXRGeminiGenerateStream` reassembles Gemini SSE |
| PowerShell | inherited | Uses the C# Core |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |
| All other implementations | not implemented | Native generateContent mapping follows adoption order |

Gemini SSE streaming reassembles `:streamGenerateContent?alt=sse` text deltas,
complete function calls, usage metadata, and finish reasons for every Gemini
adapter listed above.

## Plugin Host

| Language | Status | Detail |
| --- | --- | --- |
| Go | native | `pkg/plugin/host/process`; process, WASM, TCK, containment tests |
| Python | native | `ProcessHost`; JSON-Lines, token auth, health, timeout, cancel |
| TypeScript | native | `ProcessHost`; JSON-Lines, token auth, health, timeout, cancel |
| Rust | native | `plugin_process::ProcessHost`; JSON-Lines, timeout, cancel |
| C# | native | `PluginProcessHost`; JSON-Lines, timeout, cancel |
| Dart | native | `PluginProcessHost`; JSON-Lines, timeout, cancel |
| Ruby | native | `Praxo::PluginProcessHost`; JSON-Lines, timeout, cancel |
| Elixir | native | `Praxo.PluginProcess`; JSON-Lines, timeout, cancel |
| Erlang | native | `praxo_plugin_process`; JSON-Lines, timeout, cancel |
| Haskell | native | `Praxo.PluginProcess`; JSON-Lines, timeout |
| V | native | `PluginProcessHost`; JSON-Lines, timeout |
| OCaml | native | `start_plugin_process`; JSON-Lines, timeout, cancel |
| Fortran | native (C bindings) | `plugin_process_start`; JSON-Lines, timeout |
| Zig | native (C bindings) | `plugin_process.start`; JSON-Lines, timeout |
| Julia | native | `ProcessHost`; JSON-Lines, token auth, timeout |
| D | native | `ProcessHost`; JSON-Lines, token auth |
| C | native (Windows) | `PxPluginProcess`; JSON-Lines, timeout |
| Swift | native (parse-only locally) | `PluginProcessHost`; full build blocked by local SDK |
| Java | native | `plugin.ProcessHost`; JSON-Lines, token auth, timeout, cancel |
| Delphi | native | `praxo_plugin_process`; JSON-Lines, token auth |
| PHP | native | `PluginProcessHost`; JSON-Lines, token auth |
| Objective-C | native (C bindings) | `PXRPluginProcess`; JSON-Lines, token auth |
| Nim | native (C bindings) | `plugin_process.start`; JSON-Lines, token auth |
| C++ | native (C bindings) | `ProcessPluginHost`; JSON-Lines, token auth |

Manifest parsing, lifecycle states, and registry validation remain available in
every listed Core. Process host conformance does not imply WASM or container
hosting. COBOL now has a locally verified Win32 C-host ABI integration test
(`tests/run_plugin_process.py`), not a separate native supervision API.
The shared MATLAB/Octave `praxo.PluginProcess` Java adapter passes Windows
Octave echo, denial, timeout, and stop tests; MATLAB is not runtime-verified.
This adapter remains partial: binary payloads, concurrent calls, and
cancel-before-kill are not implemented.
## MCP

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/mcp`; stdio and Streamable HTTP 2025-03-26 |
| Python | native | `praxo.adapters.mcp.MCPClient`; stdio, plus `mcp_http.StreamableHTTPTransport` for Streamable HTTP 2025-03-26 |
| TypeScript | native | `src/adapters/mcp.ts`; stdio, plus `src/adapters/mcp-http.ts` for Streamable HTTP 2025-03-26 |
| Java | native | `adapters.McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 (local runtime verification pending) |
| Rust | native | `mcp::McpClient`; stdio, plus `McpClient::connect_http` over a caller-supplied `McpHttpTransport` seam for Streamable HTTP 2025-03-26 |
| C# | native | `Praxo.Core.Adapters.McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 |
| R | native (transport seam) | `mcp_client`; base R needs caller-supplied transport for stdio |
| Elixir | native | `Praxo.Mcp`; stdio, plus `Praxo.McpHttp.transport` for Streamable HTTP 2025-03-26 |
| Ruby | native | `Praxo::Adapters::MCPClient`; stdio, plus `HttpMCPTransport` for Streamable HTTP 2025-03-26 |
| PHP | native | `Praxo\Core\Adapters\MCPClient`; stdio, plus `HttpMCPTransport` for Streamable HTTP 2025-03-26 |
| Dart | native | `McpClient`; stdio, plus `McpStreamableHttpTransport` for Streamable HTTP 2025-03-26 |
| Erlang | native | `praxo_mcp`; stdio, plus `praxo_mcp_http:transport/2` for Streamable HTTP 2025-03-26 |
| Perl | native | `Praxo::Adapters::MCP`; stdio, plus `Praxo::Adapters::MCPHTTP` for Streamable HTTP 2025-03-26 |
| D | native | `praxo.mcp.McpClient`; stdio, plus `HttpMcpTransport` for Streamable HTTP 2025-03-26 |
| Delphi / Free Pascal | native | `TPraxoMcpClient`; stdio and `TPraxoHttpMcpTransport` for Streamable HTTP 2025-03-26 |
| Objective-C | native | `PXRMcpClient`; stdio and `PXRHttpMcpTransport` for Streamable HTTP 2025-03-26 |
| Zig | native | `mcp.Client`; stdio and curl-backed `HttpTransport` for Streamable HTTP 2025-03-26 |
| Swift | native | `McpClient`, `StdioMcpTransport`, `HttpMcpTransport`; typechecked locally, full build blocked |
| Lua | native (transport seam) | `praxo.adapters.mcp`; caller supplies transport |
| C | native (transport seam) | `PxMcpClient`; caller supplies `PxMcpTransport` |
| C++ | native (transport seam) | `McpClient`; caller supplies `McpTransport` |
| Fortran | native (transport seam) | `mcp_client`; caller supplies transport |
| COBOL | native (transport seam) | `praxo-mcp`; caller supplies a transport program |
| PowerShell | native (C# shared runtime) | `Connect-PraxoMcp`, `Get-PraxoMcpTools`, `Invoke-PraxoMcpTool`; wraps the C# MCP client and stdio/Streamable HTTP transports |
| Haskell | native (transport seam) | `Praxo.Mcp`; caller supplies `McpTransport` |
| Julia | native (transport seam) | `mcp_client`; caller supplies transport |
| MATLAB | native (transport seam) | `praxo.mcp_client`; caller supplies a function handle |
| GNU Octave | native (transport seam) | Shared `praxo.mcp_client` implementation |
| Nim | native (transport seam) | `praxo/adapters/mcp`; caller supplies transport |
| OCaml | native (transport seam) | `mcp_client`; caller supplies transport |
| V | native (transport seam) | `praxo.mcp`; caller supplies `McpTransport` |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |
| All other implementations | not implemented | MCP clients follow the model baseline in adoption order. Missing clients are not yet implemented, not a documented language limitation: a native stdio client or a caller-supplied request/response transport seam is feasible wherever the runtime can provide the transport. |

MCP support means a minimal client session that can initialize, list tools with
pagination, and call a tool. It does not imply a hosted MCP service, schema
promotion, or production authentication. The Go reference provides stdio and
Streamable HTTP 2025-03-26. Streamable HTTP clients also exist for Python,
TypeScript, C#, Java, Rust (caller-supplied seam), Ruby, PHP, Elixir, Erlang,
Dart, Perl, D, Delphi, Objective-C, and Zig; Swift defines an HTTP transport but
its full local build verification is blocked. R, Lua, C, C++, Fortran, COBOL,
Haskell, Julia, MATLAB, GNU Octave, Nim, OCaml, and V provide caller-supplied
transport seams; PowerShell wraps the C# client and transports. No live MCP
server or remote-service evidence is claimed.

COBOL now uses a caller-supplied transport program and the existing native JSON
utilities; MCP is JSON-RPC, so a native stdio child process is not required.
COBOL's separate OpenAI-compatible gap remains a model-callback concern: the
current model callback does not receive tool specs or assistant tool-call
history.

## Harmovela

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/harmovela` |
| Python | native | `praxo.adapters.harmovela.HarmovelaSink` |
| TypeScript | native | `src/adapters/harmovela.ts` |
| Java | native | `adapters.HarmovelaSink` |
| Rust | native | `harmovela::Sink` |
| C# | native | `Praxo.Core.HarmovelaSink` |
| R | native | `harmovela_sink` |
| Elixir | native | `Praxo.HarmovelaSink` |
| Ruby | native | `Praxo::Adapters::HarmovelaSink` |
| PHP | native | `Praxo\Core\Adapters\HarmovelaSink` |
| Lua | native | `praxo.harmovela_sink` |
| Nim | native | `newHarmovelaSink` |
| Perl | native | `Praxo::Adapters::Harmovela` |
| Erlang | native | `praxo_harmovela` |
| Julia | native | `HarmovelaSink` |
| V | native | `harmovela_sink`; verified with V 0.5.2 and `x.json2` |
| D | native | `HarmovelaSink` |
| Dart | native | `HarmovelaSink` |
| Haskell | native (transport seam) | `Praxo.Harmovela`; caller supplies transport |
| Swift | native | `HarmovelaSink` with URLSession transport |
| OCaml | native (transport seam) | `harmovela_sink`; caller supplies transport |
| Delphi / Free Pascal | native | `TPraxoHarmovelaSink` |
| Objective-C | native | `PraxoHarmovela` |
| MATLAB | native | `praxo.harmovela_sink` |
| GNU Octave | native | Shared `praxo.harmovela_sink` |
| Zig | native | `harmovela` |
| C | native (transport seam) | `praxo_harmovela`; caller supplies HTTP transport |
| C++ | native (transport seam) | `HarmovelaSink`; caller supplies HTTP transport |
| Fortran | native (transport seam) | `harmovela`; caller supplies HTTP transport |
| PowerShell | inherited | Uses the C# Core |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |
| COBOL | native (transport seam) | `praxo-harmovela`; caller supplies a transport program |
| Other implementations | not implemented | Add with a named consumer or maintainer |

Harmovela support means an HTTP event sink that posts the documented envelope.
It does not imply authentication, delivery guarantees, ordering, or production
transport. Each implementation uses an injected transport or loopback fixture in
tests; no live Harmovela service is claimed.

## OpenTelemetry

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/otel` maps events to spans through a `trace.Tracer` |
| Python | native (transport seam) | `praxo.adapters.otel.OtelSink`; caller supplies OTLP/HTTP transport |
| TypeScript | native (transport seam) | `src/adapters/otel.ts`; caller supplies OTLP/HTTP transport |
| Java | native (transport seam) | `adapters.OtelSink`; caller supplies OTLP/HTTP transport |
| Rust | native (transport seam) | `adapters::otel::Sink`; caller supplies OTLP/HTTP transport |
| R | native (transport seam) | `otel_sink`; caller supplies OTLP/HTTP transport |
| C# | native (transport seam) | `Praxo.Core.OtelSink`; caller supplies OTLP/HTTP transport |
| Ruby | native (transport seam) | `OtelSink`; caller supplies OTLP/HTTP transport |
| PHP | native (transport seam) | `OtelSink`; caller supplies OTLP/HTTP transport |
| Perl | native (transport seam) | `Praxo::Adapters::Otel`; caller supplies transport |
| Elixir | native (transport seam) | `Praxo.OtelSink`; caller supplies OTLP/HTTP transport |
| Dart | native (transport seam) | `OtelSink`; caller supplies `OtelTransport` |
| Lua | native (transport seam) | `adapters.otel_sink`; caller supplies OTLP/HTTP transport |
| C | native (transport seam) | `PxOtelSink`; caller supplies `PxOtelTransport` |
| C++ | native (transport seam) | `OtelSink`; caller supplies `OtelTransport` |
| Fortran | native (transport seam) | `otel_sink`; caller supplies transport |
| Haskell | native (transport seam) | `Praxo.Otel`; caller supplies `OtelTransport` |
| OCaml | native (transport seam) | `otel_sink_new` and `otel_emit`; caller supplies OTLP/HTTP transport |
| Swift | native (transport seam) | `OtelSink`; caller supplies `OtelTransport` |
| D | native (transport seam) | `OtelSink`; caller supplies OTLP/HTTP transport |
| Delphi / Free Pascal | native (transport seam) | `TPraxoOtelSink`; caller supplies `TPraxoOtelTransport` |
| Objective-C | native (transport seam) | `PXROtelSink`; caller supplies `PXROtelTransport` |
| Nim | native (transport seam) | `newOtelSink`; caller supplies OTLP/HTTP transport |
| V | native (transport seam) | `new_otel_sink`; caller supplies `OtelTransport` |
| Zig | native (transport seam) | `otel.Sink`; caller supplies OTLP/HTTP transport |
| Julia | native (transport seam) | `otel_sink`; caller supplies OTLP/HTTP transport |
| MATLAB | native (transport seam) | `praxo.otel_sink`; caller supplies OTLP/HTTP transport |
| GNU Octave | native (transport seam) | Shared `praxo.otel_sink`; caller supplies OTLP/HTTP transport |
| Erlang | native (transport seam) | `praxo_otel`; caller supplies transport |
| COBOL | native (transport seam) | `praxo-otel`; caller supplies an OTLP/HTTP transport program |
| PowerShell | inherited | Uses the C# Core |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |
| All other implementations | not implemented | Candidate transport-seam sinks; no OpenTelemetry SDK dependency is required |

OpenTelemetry support means mapping Core events to OTLP spans over a
caller-supplied transport. It does not imply a collector, sampler, SDK,
production exporter, or vendor backend. Event data is excluded by default;
selected keys must be allowlisted explicitly.

## Delegation

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `pkg/agent/delegation` subagent manager |
| Python | native | `praxo.delegation.SubagentManager` |
| TypeScript | native | `src/delegation.ts` `SubagentManager` |
| Java | native | `agent.delegation.SubagentManager` |
| Rust | native | `delegation::SubagentManager` |
| C# | native | `Praxo.Core.Delegation.SubagentManager` |
| R | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Ruby | native | `Delegation::SubagentManager` |
| PHP | native (synchronous seam) | `SubagentManager::run`; no asynchronous manager |
| Perl | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Elixir | native | `Praxo.SubagentManager` |
| Dart | native (synchronous seam) | `SubagentManager.run`; no asynchronous manager |
| Lua | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| C | native (synchronous seam) | `px_subagent_run`; no asynchronous manager |
| C++ | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Fortran | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Haskell | native (synchronous seam) | `Praxo.Delegation.subagentRun`; no asynchronous manager |
| OCaml | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| Swift | native (synchronous seam) | `SubagentManager.run`; no asynchronous manager |
| D | native (synchronous seam) | `SubagentManager.run` in `praxo.delegation`; no asynchronous manager |
| Delphi / Free Pascal | native (synchronous seam) | `TPraxoSubagentManager.Run`; no asynchronous manager |
| Objective-C | native (synchronous seam) | `PXRSubagentRun`; no asynchronous manager |
| Nim | native (synchronous seam) | `subagentRun`; no asynchronous manager |
| V | native (synchronous seam) | `SubagentManager.run`; no asynchronous manager |
| Zig | native (synchronous seam) | `delegation.subagentRun`; no asynchronous manager |
| Julia | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| MATLAB | native (synchronous seam) | `praxo.subagent_run`; no asynchronous manager |
| GNU Octave | native (synchronous seam) | Shared `praxo.subagent_run`; no asynchronous manager |
| Erlang | native (synchronous seam) | `praxo_delegation:subagent_run/2`; no asynchronous manager |
| PowerShell | native (synchronous wrapper) | Reuses C# request/result/task types; no asynchronous manager |
| COBOL | native (synchronous seam) | `praxo-delegation`; synchronous runner callback; no asynchronous manager |
| All other implementations | not implemented | Add with a named consumer or maintainer |

Delegation means a local child-run manager with queued/running/terminal states,
wait, optional update, and cancellation. It does not imply durable remote
workers, cross-process scheduling, or exactly-once execution.

## Retriever

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `pkg/retriever.Document` and `Retriever` |
| Python | native | `praxo.retriever.Document` and `Retriever` |
| TypeScript | native | `src/retriever.ts` `Document` and `Retriever` |
| Java | native | `retriever.Document` and `Retriever` |
| Rust | native | `retriever::Document` and `Retriever` |
| C# | native | `Praxo.Core.Retriever.Document` and `Retriever` |
| R | native | `document`, `func_retriever`, `retriever_retrieve` |
| Ruby | native | `Document`, `FuncRetriever` |
| PHP | native | `Document`, `Retriever`, `FuncRetriever` |
| Perl | native | `document`, `func_retriever`, `retrieve_documents` |
| Elixir | native | `Praxo.Document`, `Praxo.FuncRetriever` |
| Dart | native | `Document`, `FuncRetriever`, `retrieveDocuments` |
| Lua | native | `document`, `func_retriever`, `retriever_retrieve` |
| C | native | `PxDocument`, `PxRetriever`, `px_retrieve` |
| C++ | native | `Document`, `Retriever`, `retrieve` |
| Fortran | native | `document`, `retriever`, `retrieve_documents` |
| Haskell | native | `Praxo.Retriever.Document` and `Retriever` |
| OCaml | native | `document` and `retrieve_documents` |
| Swift | native | `Document`, `FuncRetriever`, `retrieveDocuments` |
| D | native | `Document`, `Retriever`, `FuncRetriever`, `retrieveDocuments` |
| Delphi / Free Pascal | native | `TPraxoDocument`, `TPraxoRetriever`, `PraxoRetrieveDocuments` |
| Objective-C | native | `PXDocument`, `PXRetriever`, `PXRetrieveDocuments` |
| Nim | native | `Document`, `Retriever`, `FuncRetriever`, `retrieveDocuments` |
| V | native | `Document`, `Retriever`, `FuncRetriever`, `retrieve_documents` |
| Zig | native | `retriever.Document`, `retriever.Retriever`, `retriever.retrieveDocuments` |
| Julia | native | `Document`, `FuncRetriever`, `retrieve_documents` |
| MATLAB | native | `praxo.document` and `praxo.retrieve_documents` |
| GNU Octave | native | Shared `praxo.document` and `praxo.retrieve_documents` |
| Erlang | native | `praxo_retriever:document`, `func_retriever`, `retrieve/3` |
| PowerShell | inherited (wrapper) | Wraps C# `Retriever` |
| COBOL | native | `praxo-retriever`; callback seam over query and limit |
| All other implementations | not implemented | Add with a named consumer or maintainer |

Retriever support means a document/query/limit seam. It does not define an
embedding model, vector database, ranking service, or production search quality.

## Adding a Native Adapter

1. Follow the language's existing model, tool, or event seam; do not widen the Go
   API for a port.
2. Add a deterministic test with an injected transport or a loopback fixture.
3. Update this page and the language README or REGISTRY entry.
4. Run the language's conformance, API snapshot, and native tests.
5. State streaming, dependency, and provider-verification limits explicitly.
