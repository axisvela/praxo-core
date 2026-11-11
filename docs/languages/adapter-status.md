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
| V | native | `praxo.openaicompat`; local V toolchain unavailable, CI gate |
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
| COBOL | not implemented | No HTTP transport; model callback lacks tool specs/history |
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
| All other implementations | not implemented | Native generateContent mapping follows adoption order |

## MCP

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/mcp` |
| Python | native | `praxo.adapters.mcp.MCPClient`; stdio JSON-RPC with fake-server tests |
| TypeScript | native | `src/adapters/mcp.ts`; stdio JSON-RPC with fake-server tests |
| Java | native | `adapters.McpClient`; stdio JSON-RPC with fake-server self-test |
| Rust | native | `mcp::McpClient`; stdio JSON-RPC with fake-server tests |
| C# | native | `Praxo.Core.Adapters.McpClient`; stdio JSON-RPC with fake-server tests |
| R | native (transport seam) | `mcp_client`; base R needs caller-supplied transport for stdio |
| Elixir | native | `Praxo.Mcp`; stdio JSON-RPC with fake-server tests |
| All other implementations | not implemented | Native MCP clients follow the model baseline in adoption order |

MCP support means a minimal client session that can initialize, list tools with
pagination, and call a tool. It does not imply a hosted MCP service, schema
promotion, or production authentication. The Python and TypeScript clients are
stdio pilots; no live MCP server or remote transport is claimed.

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
| V | native | `harmovela_sink`; local V toolchain unavailable, CI gate |
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
| COBOL | not implemented | No HTTP transport; no event sink integration |
| Other implementations | not implemented | Add with a named consumer or maintainer |

Harmovela support means an HTTP event sink that posts the documented envelope.
It does not imply authentication, delivery guarantees, ordering, or production
transport. Each implementation uses an injected transport or loopback fixture in
tests; no live Harmovela service is claimed.

## Adding a Native Adapter

1. Follow the language's existing model, tool, or event seam; do not widen the Go
   API for a port.
2. Add a deterministic test with an injected transport or a loopback fixture.
3. Update this page and the language README or REGISTRY entry.
4. Run the language's conformance, API snapshot, and native tests.
5. State streaming, dependency, and provider-verification limits explicitly.
