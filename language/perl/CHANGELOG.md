# Perl Core Release Notes

## 0.5.0 - 2026-11-15

Source tag `perl/v0.5.0`.

### Added

- Opt-in `require_policy` guard: agent construction fails with
  `AGENT_INVALID_OPTIONS` when a policy is required but no policy hook is
  configured.
- Opt-in `require_tool_scope` guard: agent construction fails with
  `AGENT_INVALID_OPTIONS` when tool scope is required but `allowed_tools` is
  empty.

## 0.4.0 - 2026-11-13

Source tag `perl/v0.4.0`.

### Added

- OpenTelemetry OTLP/HTTP sink over an injected transport.
- Retriever document/query/limit seam with `document`, `func_retriever`, and
  `retrieve_documents`.
- Synchronous subagent delegation seam with `subagent_run`.

## 0.3.0 - 2026-11-12

Source tag `perl/v0.3.0`.

### Added

- MCP Streamable HTTP (2025-03-26) transport and client support.
