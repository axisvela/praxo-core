# COBOL Core Release Notes

## 0.6.0 - 2026-11-13

Source release tag `cobol/v0.6.0`. This is not a package-registry release.

### Added

- Transport-seam Anthropic Messages adapter (`praxo-anthropic`) with system
  message mapping, tool declarations, tool choice, text and tool-use parsing,
  usage parsing, and provider HTTP/JSON errors.
- Transport-seam Gemini `generateContent` adapter (`praxo-gemini`) with system
  instructions, tool declarations, tool choice, text and function-call parsing,
  usage parsing, and provider HTTP/JSON errors.
- Transport-seam OpenTelemetry OTLP/HTTP sink (`praxo-otel`) with deterministic
  trace and span identifiers, default event-data exclusion, explicit key
  allowlists, and bounded non-2xx error bodies. No OpenTelemetry SDK dependency.
- Retriever seam (`praxo-retriever`) with a document record, callback program,
  query and limit forwarding, and `RETRIEVER_INVALID` validation.
- Synchronous delegation seam (`praxo-delegation`) with request, result, and
  task records, completed/failed terminal states, preserved runner error codes,
  and `SUBAGENT_INVALID` validation.
- Native test suites for the new adapters and seams.
- API snapshot `api/0.6.0.txt`.

## 0.5.0 - 2026-11-13

Source release tag `cobol/v0.5.0`. This is not a package-registry release.

### Added

- Transport-seam MCP client (`praxo-mcp`) with initialize, paginated tool
  listing, duplicate-tool and repeated-cursor rejection, tool calls, and close.
- Transport-seam Harmovela event sink (`praxo-harmovela`) with the shared
  envelope, 2xx success handling, and bounded non-2xx errors.
- Transport-seam OpenAI-compatible model adapter (`praxo-openai`) with
  configurable base URL and model, message mapping, usage parsing, and
  assistant tool-call parsing. The COBOL model callback still does not pass
  tool specs or assistant tool-call history to model adapters.

## 0.4.0 - 2026-11-02

Source release tag `cobol/v0.4.0`. This is not a package-registry release.

### Added

- Human-in-the-loop interrupt decisions through `px-interrupt-program`,
  `px-interrupt-count`, and `px-interrupt-tools`.
- A `px-interrupt` callback record supports approve/edit/reject/respond.
  Interrupted calls emit `tool.interrupt`; edited arguments are reauthorized.
- API snapshot `api/0.4.0.txt`.

## 0.3.0 - 2026-11-01

Source version `0.3.0`; tag creation is a release step.

### Added

- Cancellation callback program with model and tool cancellation cleanup.
- Stream callback parts (`values`, `messages`) and fail-closed stream errors.
- Native `praxo-sse` parser that rejects truncated and half-packet streams.
- Caller-provided batch tool dispatcher with `px-max-parallel-tools`, ordered
  results, and `tool-batch.cpy`.
- Native behavior and SSE suites; all nineteen behavior scenarios are covered.
- API snapshot `api/0.3.0.txt`.

### Compatibility

- New `px-options` components are additive; consumers must recompile against the
  new copybook.
- Parallel tool execution is delegated to the batch dispatcher. The native test
  verifies the batch limit and result order, not OS-level thread concurrency.
- The Core contract remains `SPEC_VERSION` `0.2.0`.

## 0.2.0 - 2026-11-01

Source version `0.2.0`; tag creation is a release step.

### Added

- Optional before-run, after-run, and before-tool callback programs in
  `px-options`.
- Final tool-name allowlist checks and reauthorization of middleware-mutated
  names or arguments.
- Lifecycle cleanup for startup failures, after-run continuation, and
  fail-closed cleanup errors.
- Native behavior cases for the seven authorization and lifecycle scenarios.
- API snapshot `api/0.2.0.txt`.

### Compatibility

- New `px-options` components are additive; consumers must recompile against the
  new copybook.
- Cancellation, streaming, SSE, parallel tools, and run-state isolation remain
  unsupported.
- The Core contract remains `SPEC_VERSION` `0.2.0`.
