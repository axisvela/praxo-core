# PRAXO-CORE Contract Specification

`spec/` is the normative, language-neutral contract for the Python, TypeScript,
Java, and independent Core implementations listed in
[`languages.md`](languages.md). Go remains the reference implementation in
`pkg/...`.

When this directory and the Go implementation disagree, that is a bug. The
specification is normative; Go is used to discover and verify it.

## Layout

```text
spec/
  SPEC_VERSION        contract version, independent of Core versions
  README.md           this file
  languages.md        language tiers, status, and tags
  bridge.md           process contract for shell and PowerShell bridges
  parity.md           Go symbol -> Core symbol inventory
  parity/             per-language inventories for newer Core implementations
  wire/               JSON envelopes, events, errors, schema, plugin contract
  vectors/            language-neutral behavior fixtures
```

Implemented:

- `wire/` event, error, JSON Schema, and plugin contracts
- `vectors/` groups for agent loop, toolcall, JSON Schema, plugin, memory,
  event, stream, checkpoint, policy, context, and middleware
- Go runner and parity linter in `internal/spec`, run by CI job
  `spec-conformance`
- Python runner and parity check in `language/python/praxo/conformance.py`, run by CI job
  `python-conformance`

Planned additions:

- `wire/tools.json` for the tool spec and gateway shapes
- `wire/model.json` for messages, tool calls, and usage
- `wire/checkpoint.json` for the snake_case checkpoint envelope

## Normative Rules

1. Wire names are frozen as they exist today. Do not normalize casing. `image_url`
   stays snake_case; `tenantId`, `workspaceId`, `runId`, and `sessionId` stay
   camelCase.
2. A wire change (field, event, stream kind, plugin envelope, error code) is
   breaking for every Core implementation.
3. A behavioral change requires a vector update and a minor release of the Core implementation.
4. A Core implementation may not implement a contract capability that the Go reference lacks.
5. Source APIs map one-to-one but use idiomatic names. They are not required to
   be name-identical.
6. Cross-Core dependencies and FFI are out of scope.

## Versioning

- `SPEC_VERSION` starts at `0.1.0`; the current contract is `0.2.0`.
- Additive contract changes bump the minor version.
- Removing or renaming a wire artifact bumps the major version.
- `spec/vX.Y.Z` tags never move.
- Each Core implementation release declares the `SPEC_VERSION` it implements.

## Running Vectors

Every Core implementation provides a runner that consumes `vectors/**/*.json` and reports
`{vector id, pass|fail, detail}`. CI fails on any mismatch for a released Core implementation.
The Go runner is built first and is the authority for whether a vector is
correct.

A runner must fail on a missing required group, an empty group, an unknown
group, a version mismatch, or a duplicate vector ID. Reporting success while a
group was not discovered is not conformance. Required groups currently are
`agent-loop`, `checkpoint`, `context`, `event`, `jsonschema`, `memory`,
`middleware`, `plugin`, `policy`, `stream`, and `toolcall`; adding a group
requires updating each runner and its inventory gate.

See [Multilingual Core design](../docs/contributing/core-design.md) and the
[Core support policy](../docs/languages/support.md).

## License

MIT. See [LICENSE](../LICENSE).
