# PRAXO-CORE Contract Specification

`spec/` is the normative, language-neutral contract for the Python, TypeScript,
and Java SDKs. Go remains the reference implementation in `pkg/...`.

When this directory and the Go implementation disagree, that is a bug. The
specification is normative; Go is used to discover and verify it.

## Layout

```text
spec/
  SPEC_VERSION        contract version, independent of SDK versions
  README.md           this file
  languages.md        language tiers, status, and tags
  bridge.md           process contract for shell and PowerShell bridges
  parity.md           Go symbol -> core SDK symbol inventory
  parity/             per-language inventories for newer SDKs
  wire/               JSON envelopes, events, errors, schema, plugin contract
  vectors/            language-neutral behavior fixtures
```

Implemented:

- `wire/` event, error, JSON Schema, and plugin contracts
- `vectors/` groups for agent loop, toolcall, JSON Schema, plugin, memory,
  event, stream, checkpoint, policy, context, and middleware
- Go runner and parity linter in `internal/spec`, run by CI job
  `spec-conformance`
- Python runner and parity check in `sdk/python/praxo/conformance.py`, run by CI job
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
   breaking for every SDK.
3. A behavioral change requires a vector update and an SDK minor release.
4. An SDK may not implement a contract capability that the Go reference lacks.
5. Source APIs map one-to-one but use idiomatic names. They are not required to
   be name-identical.
6. Cross-SDK dependencies and FFI are out of scope.

## Versioning

- `SPEC_VERSION` starts at `0.1.0`; the current contract is `0.2.0`.
- Additive contract changes bump the minor version.
- Removing or renaming a wire artifact bumps the major version.
- `spec/vX.Y.Z` tags never move.
- Each SDK release declares the `SPEC_VERSION` it implements.

## Running Vectors

Every SDK provides a runner that consumes `vectors/**/*.json` and reports
`{vector id, pass|fail, detail}`. CI fails on any mismatch for a released SDK.
The Go runner is built first and is the authority for whether a vector is
correct.

See [Multilingual SDK design](../docs/contributing/sdk-design.md) and the
[SDK support policy](../docs/languages/support.md).

## License

MIT. See [LICENSE](../LICENSE).
