# Conformance Vectors

Vectors are the executable definition of behavioral parity. A vector is
language-neutral JSON; every SDK ships a runner that executes it.

## Layout

```text
spec/vectors/
  agent-loop.json       implemented
  toolcall.json         implemented
  jsonschema.json       implemented
  plugin.json           implemented
  memory.json           implemented
  event.json            implemented
  stream.json           implemented
  checkpoint.json       implemented
  policy.json           implemented
  context.json          implemented
  middleware.json       implemented
```

Each file is one group. Files are added only after the Go runner passes them.

## File Shape

```json
{
  "specVersion": "0.1.0",
  "group": "toolcall",
  "vectors": [
    {
      "id": "toolcall.json-object",
      "description": "Parse a JSON object argument",
      "input": {},
      "expect": {}
    }
  ]
}
```

Rules:

- `id` is stable and unique across the whole tree.
- `group` matches the file name.
- `input` and `expect` are owned by the group; this README does not constrain
  their internal shape beyond determinism.
- `expect.error.code` uses a code from `spec/wire/errors.json`. Messages are not
  compared.
- `expect.events` compares `type`, `sessionId`, `runId`, and `data`. The `at`
  field is not compared.
- Implementations must not rewrite, sort, or normalize fixtures to pass.

## Runner Contract

A runner:

1. Reads every `spec/vectors/**/*.json`.
2. Filters by the groups the SDK implements.
3. Executes each vector in a fresh state.
4. Reports `{id, status, detail}` for every vector.
5. Exits non-zero on any failure, including a missing required group.

The Go runner is the authority. If Go fails a vector, the vector is wrong until
reviewed; if an SDK fails a vector that Go passes, the SDK has a parity bug.

## Status

The Go and Python runners execute all eleven groups; every group passes in
both. No vector file is normative until it passes the Go runner.

Run locally:

```bash
GOWORK=off go test -count=1 ./internal/spec/... -v
cd python && python conformance/run.py
```

See the [multilingual roadmap](../../docs/18-multilingual-roadmap.md).
