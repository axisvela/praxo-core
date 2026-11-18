# Perl Core Release Notes

## 0.6.2 - 2026-11-18

Source tag `perl/v0.6.2`; CPAN publication follows the release workflow.

### Added

- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation example plus six application-level governance checks.

### Compatibility

- No public API or wire change; `SPEC_VERSION` remains `0.2.0`.

## 0.6.1 - 2026-11-17

Source tag `perl/v0.6.1`.

### Changed

- Clarified the CPAN classification: `Praxo::Core` is an embeddable AI agent
  framework, not an HTTP user agent, web crawler, or hosted agent service.
  Added `NAME` and `DESCRIPTION` POD and updated the Makefile abstract.

## 0.6.0 - 2026-11-15

Source tag `perl/v0.6.0`.

### Added

- Human-in-the-loop interrupt decisions through `interrupt_on`,
  `on_interrupt_decision`, and `on_interrupt` agent options.
- `Praxo::Models::interrupt`, `interrupt_decision`, and the
  `INTERRUPT_APPROVE`/`EDIT`/`REJECT`/`RESPOND` actions. Interrupted calls emit
  `tool.interrupt`, edits are reauthorized before execution, rejects raise
  `AGENT_APPROVAL_DENIED`, responds skip the tool, and invalid decisions raise
  `AGENT_INTERRUPT_DECISION_INVALID`.

## 0.5.1 - 2026-11-15

### Changed

- Expanded the registry README with a Get started section and a task-oriented example index.

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
