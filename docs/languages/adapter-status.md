# Adapter Status

This page tracks native adapter coverage for Model providers, MCP tool sessions,
and Harmovela event delivery. Contract conformance and behavior coverage are
separate; an adapter is not production or provider evidence.

Status words:

- `native`: an in-tree adapter for this implementation.
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
| PowerShell | inherited | Uses the C# Core |
| Visual Basic / F# | inherited | Samples over the C# Core |
| Kotlin / Scala / Groovy / Clojure | inherited | Samples over the Java Core |
| JavaScript | inherited | Sample over the TypeScript Core |
| Shell / Lisp / Tcl / Prolog | bridge | Uses the Go Core through the bridge |
| R | not implemented | Batch 2 |
| Erlang | not implemented | Batch 2 |
| Julia | not implemented | Batch 2 |
| V | not implemented | Batch 2 |
| Dart | not implemented | Needs an async model path or a synchronous HTTP helper |
| Haskell | not implemented | Needs an HTTP client dependency decision |
| Swift | not implemented | Batch 3 |
| OCaml | not implemented | Batch 3 |
| Delphi / Free Pascal | not implemented | Batch 3 |
| Objective-C | not implemented | Batch 3 |
| MATLAB / Octave | not implemented | Batch 3 |
| Zig | not implemented | Batch 3 |
| C | not implemented | Needs an HTTP/JSON dependency decision |
| C++ | not implemented | Needs an HTTP/JSON dependency decision |
| Fortran | not implemented | Needs an HTTP/JSON dependency decision |
| COBOL | not implemented | Needs an HTTP/JSON dependency decision |

The baseline mapping is documented in the
[OpenAI-compatible model adapter](../reference/openai-compatible-adapter.md).

## MCP

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/mcp` |
| All other implementations | not implemented | Native MCP clients are the next adapter track after the model baseline |

MCP support means a minimal client session that can initialize, list tools with
pagination, and call a tool. It does not imply a hosted MCP service, schema
promotion, or production authentication.

## Harmovela

| Language | Status | Notes |
| --- | --- | --- |
| Go | native | `adapters/harmovela` |
| All other implementations | not implemented | Native HTTP event sinks follow the MCP track |

Harmovela support means an HTTP event sink that posts the documented envelope.
It does not imply authentication, delivery guarantees, or production transport.

## Adding a Native Adapter

1. Follow the language's existing model, tool, or event seam; do not widen the Go
   API for a port.
2. Add a deterministic test with an injected transport or a loopback fixture.
3. Update this page and the language README or REGISTRY entry.
4. Run the language's conformance, API snapshot, and native tests.
5. State streaming, dependency, and provider-verification limits explicitly.
