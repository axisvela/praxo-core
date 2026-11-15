# OCaml Core Release Notes

## 0.7.0 - 2026-11-15

Source tag `ocaml/v0.7.0`.

### Added

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
