# Adapter Status

This page tracks native adapter coverage for Model providers, MCP tool sessions,
and Harmovela event delivery. Contract conformance and behavior coverage are
separate; an adapter is not production or provider evidence.

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
| Rust | native | `openai_compat` |
| C# | native | `Praxo.Core.OpenAiCompatible` |
| Ruby | native | `Praxo::Adapters::OpenAICompatible` |
| PHP | native | `Praxo\Core\Adapters\OpenAICompatible` |
| Elixir | native | `Praxo.OpenAICompatible` |
| Lua | native | `praxo.openai_compatible` |
| Perl | native | `Praxo::Adapters::OpenAICompatible` |
| Nim | native | `praxo/adapters/openai_compatible` |
| R | native | `openai_compatible` adapter |
| Erlang | native | `praxo_openai_compatible` |
| Julia | native | `OpenAICompatibleModel` |
| V | native | `praxo.openaicompat`; verified with V 0.5.2 and `x.json2` |
| Dart | native | `OpenAiCompatibleModel` with sync and async transport paths |
| Haskell | native (transport seam) | Caller supplies `Transport`; no bundled HTTP client |
| Swift | native | `OpenAICompatibleModel` with URLSession transport |
| OCaml | native (transport seam) | Caller supplies `transport`; no bundled HTTP client |
| Delphi / Free Pascal | native | `TPraxoOpenAIAdapter` with FPC HTTP transport |
| Objective-C | native | `PXROpenAIGenerate` with injectable transport |
| MATLAB | native | `praxo.openai_compatible` using `webwrite` |
| GNU Octave | native | Shared `praxo.openai_compatible` implementation |
| Zig | native | `openaicompat.Adapter` with `std.http` |
| C | native (transport seam) | `PxOpenAICompatible`; caller supplies HTTP transport |
| C++ | native (transport seam) | `OpenAICompatible`; caller supplies HTTP transport |
| Fortran | native (transport seam) | `openai_compatible`; caller supplies HTTP transport |
| D | native (transport seam) | `OpenAICompatibleModel`; caller may inject transport |
| COBOL | native (transport seam) | `praxo-openai`; caller supplies a transport program; the model callback lacks tool specs/history |
| PowerShell | inherited | Uses the C# Core |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |

The baseline mapping is documented in the
[OpenAI-compatible model adapter](../reference/openai-compatible-adapter.md).
OpenAI, DeepSeek, Kimi/Moonshot, OpenRouter, Groq, and Together use this adapter
with different base URLs; the Python and TypeScript implementations expose
provider presets.

## Model (Anthropic Native)

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/anthropic` |
| Python | native | `praxo.adapters.anthropic.AnthropicModel` |
| TypeScript | native | `src/adapters/anthropic.ts` |
| C# | native | `Praxo.Core.AnthropicModel` |
| R | native (transport seam) | `anthropic`; caller may supply `transport` |
| Elixir | native | `Praxo.Anthropic` |
| Java | native | `adapters.AnthropicModel` |
| Rust | native (transport seam) | `adapters::anthropic`; caller supplies transport |
| Ruby | native | `Praxo::Adapters::Anthropic`; injectable transport |
| PHP | native | `Praxo\Core\Adapters\Anthropic` |
| Lua | native | `praxo.adapters.anthropic` |
| Perl | native | `Praxo::Adapters::Anthropic` |
| Dart | native | `AnthropicModel` with sync and async transport paths |
| Erlang | native | `praxo_anthropic` |
| D | native (transport seam) | `AnthropicModel`; caller may inject transport |
| C | native (transport seam) | `PxAnthropic`; caller supplies HTTP transport |
| C++ | native (transport seam) | `Anthropic`; caller supplies HTTP transport |
| Fortran | native (transport seam) | `anthropic_compatible`; caller supplies HTTP transport |
| Julia | native | `AnthropicModel`; injectable transport |
| Nim | native | `newAnthropicCompatible`; injectable transport |
| Haskell | native (transport seam) | `Praxo.Anthropic`; caller supplies transport |
| OCaml | native (transport seam) | `anthropic_model`; caller supplies transport |
| Swift | native | `AnthropicModel` with injectable transport |
| V | native (transport seam) | `anthropic_compatible`; caller supplies `ProviderTransport` |
| Zig | native | `anthropic.Adapter`; injectable transport |
| MATLAB | native | `praxo.anthropic_compatible`; injectable transport |
| GNU Octave | native | Shared `praxo.anthropic_compatible` |
| Delphi / Free Pascal | native | `TPraxoAnthropicAdapter`; FPC HTTP transport |
| Objective-C | native | `PXRAnthropicGenerate` with injectable transport |
| PowerShell | inherited | Uses the C# Core |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |
| All other implementations | not implemented | Use the OpenAI-compatible adapter only for OpenAI-compatible endpoints |

## Model (Gemini Native)

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/gemini` |
| Python | native | `praxo.adapters.gemini.GeminiModel` |
| TypeScript | native | `src/adapters/gemini.ts` |
| C# | native | `Praxo.Core.GeminiModel` |
| R | native (transport seam) | `gemini`; caller may supply `transport` |
| Elixir | native | `Praxo.Gemini` |
| Java | native | `adapters.GeminiModel` |
| Rust | native (transport seam) | `adapters::gemini`; caller supplies transport |
| Ruby | native | `Praxo::Adapters::Gemini`; injectable transport |
| PHP | native | `Praxo\Core\Adapters\Gemini` |
| Lua | native | `praxo.adapters.gemini` |
| Perl | native | `Praxo::Adapters::Gemini` |
| Dart | native | `GeminiModel` with sync and async transport paths |
| Erlang | native | `praxo_gemini` |
| D | native (transport seam) | `GeminiModel`; caller may inject transport |
| C | native (transport seam) | `PxGemini`; caller supplies HTTP transport |
| C++ | native (transport seam) | `Gemini`; caller supplies HTTP transport |
| Fortran | native (transport seam) | `gemini_compatible`; caller supplies HTTP transport |
| Julia | native | `GeminiModel`; injectable transport |
| Nim | native | `newGeminiCompatible`; injectable transport |
| Haskell | native (transport seam) | `Praxo.Gemini`; caller supplies transport |
| OCaml | native (transport seam) | `gemini_model`; caller supplies transport |
| Swift | native | `GeminiModel` with injectable transport |
| V | native (transport seam) | `gemini_compatible`; caller supplies `ProviderTransport` |
| Zig | native | `gemini.Adapter`; injectable transport |
| MATLAB | native | `praxo.gemini_compatible`; injectable transport |
| GNU Octave | native | Shared `praxo.gemini_compatible` |
| Delphi / Free Pascal | native | `TPraxoGeminiAdapter`; FPC HTTP transport |
| Objective-C | native | `PXRGeminiGenerate` with injectable transport |
| PowerShell | inherited | Uses the C# Core |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |
| All other implementations | not implemented | Native generateContent mapping follows adoption order |

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
| Elixir | native (transport seam) | `Praxo.OtelSink`; caller supplies OTLP/HTTP transport |
| Lua | native (transport seam) | `adapters.otel_sink`; caller supplies OTLP/HTTP transport |
| C | native (transport seam) | `PxOtelSink`; caller supplies `PxOtelTransport` |
| C++ | native (transport seam) | `OtelSink`; caller supplies `OtelTransport` |
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
| Elixir | native | `Praxo.SubagentManager` |
| Lua | native (synchronous seam) | `subagent_run`; no asynchronous manager |
| C | native (synchronous seam) | `px_subagent_run`; no asynchronous manager |
| C++ | native (synchronous seam) | `subagent_run`; no asynchronous manager |
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
| Elixir | native | `Praxo.Document`, `Praxo.FuncRetriever` |
| Lua | native | `document`, `func_retriever`, `retriever_retrieve` |
| C | native | `PxDocument`, `PxRetriever`, `px_retrieve` |
| C++ | native | `Document`, `Retriever`, `retrieve` |
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
