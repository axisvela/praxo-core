# OCaml Core Release Notes

## 0.10.0 - 2026-11-26

Source tag `ocaml/v0.10.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.9.0 - 2026-11-20

Source tag `ocaml/v0.9.0`.

### Added

- Deterministic representative-chain example covering MCP, final-argument
  authorization, governed child delegation, OTel/Harmovela events, and an edited
  denial with zero effects.
- Advanced-delegation example plus six application-level governance checks.

## 0.8.0 - 2026-11-15

Source tag `ocaml/v0.8.0`.

### Added

- HITL interrupt decisions and session-checkpoint support.


## 0.7.0 - 2026-11-15

Source tag `ocaml/v0.7.0`.

### Added

- Human-in-the-loop interrupts with `agent_interrupt_on`,
  `agent_on_interrupt_decision`, and `agent_on_interrupt`. Decisions support
  approve, edit, reject, and respond; edited arguments are authorized again.
- `agent_action_policy` receives the action kind, session, tool name, and
  arguments for argument-aware authorization.
- `agent_require_policy` rejects `run_agent` when no policy hook is configured.
- `agent_require_tool_scope` rejects `run_agent` when `agent_allowed_tools` is
  empty.
- Both guards are opt-in and default to `false`.

## 0.6.0 - 2026-11-13

Source tag `ocaml/v0.6.0`; the split repository prepares opam package
`praxo-core` 0.3.0.

### Added

- OpenTelemetry transport-seam sink with caller-supplied delivery.
- Retriever seam with `Document`, `Retriever`, and synchronous delegation helpers.

### Changed

- Kept all eleven shared vector groups, native tests, and source API/parity
  checks green for the release.