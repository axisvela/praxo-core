# Wire Contract

This directory freezes the JSON shapes shared by every Core implementation. Names and casing are
normative. Do not "fix" casing or reorder fields to look idiomatic.

| File | Contract |
| --- | --- |
| `events.json` | `event.Event` shape, event names, data keys, stream kinds |
| `errors.json` | Exported sentinels, stable codes, Core exception names, plugin call error codes |
| `jsonschema.json` | Supported and ignored JSON Schema keywords |
| `plugin.json` | Manifest v1, kinds, states, event kinds, protocol |

Planned:

- `tools.json` for tool specs, gateway listings, and tool results
- `model.json` for messages, content blocks, tool calls, and usage

## Rules

- Field names and casing are exactly what the Go structs emit.
- Mixed casing is intentional: `image_url` is snake_case while `runId` is
  camelCase.
- Optional fields with `omitempty` may be absent; consumers must not require
  them.
- Unknown fields are rejected where the Go parser sets `DisallowUnknownFields`.
- Timestamps are RFC 3339 UTC.
- Error messages are human-readable and not part of the contract; compare codes.
