# Event and OpenTelemetry Schema

This page records the stable event names and payloads emitted by the agent loop,
plus the OpenTelemetry mapping in `adapters/otel`. It is a compatibility note,
not a delivery guarantee.

## Event Envelope

`event.Event` is the wire shape shared by every sink:

| Field | Type | Meaning |
| --- | --- | --- |
| `type` | string | Stable event name |
| `sessionId` | string | Session identity |
| `runId` | string | Run identity; may be empty outside the agent loop |
| `data` | object | Event-specific payload; may be absent |
| `at` | RFC 3339 timestamp | Emission time; set to UTC when the emitter leaves it zero |

Events are process-local notifications. `event.Sink` has no retry, delivery, or
durability guarantee. `event.MultiSink` stops at the first sink error, so a
later sink may not receive that event.

## Agent Event Types

| Type | Data keys | When |
| --- | --- | --- |
| `run.started` | none | A run enters the governed loop |
| `run.completed` | none | A run returns successfully |
| `run.failed` | `error` (string) | A run returns an error, including policy or approval denial |
| `tool.call` | `name` (string), `arguments` (object) | A tool call is about to execute |
| `tool.interrupt` | `name` (string), `arguments` (object) | A tool call is waiting for an approval decision |

`arguments` can contain tenant data, prompts, file paths, or credentials supplied
by a tool caller. Redact before persisting or exporting it.

## Stream Projections

`agent.Options.OnStream` receives `agent.StreamPart` values. They are a separate
typed projection, not `event.Sink` events:

- `values`, `updates`, `messages`, `tasks`, `debug`, `checkpoint`
- `tasks` currently carries `status`, `name`, and `arguments` for tool-task
  transitions

Treat stream projections as additive. Consumers must ignore unknown kinds and
unknown data fields.

## Compatibility Rules

- Event type strings are stable within the v2 module line. Renaming or removing
  one requires a new major version.
- New event types and new `data` keys may be added in a minor release.
- Consumers must ignore unknown event types and unknown data keys.
- `data` values must remain JSON-serializable. Nested maps and slices are
  allowed.
- Event order is emission order for one sink. Concurrent tool calls may emit
  events in completion order.
- `event.MultiSink` is fail-fast, not best-effort fan-out.
- No event payload is a durable audit record. Products that need durability must
  persist events before acknowledging the run.

## OpenTelemetry Mapping

`adapters/otel` maps one event to one span:

| Span field | Value |
| --- | --- |
| Name | `praxo.<event type>` |
| `praxo.event.type` | Event type |
| `praxo.session.id` | Session ID, when present |
| `praxo.run.id` | Run ID, when present |
| `praxo.event.at` | UTC emission time, when present |
| `praxo.event.data.<key>` | Selected data value, only through `AllowedDataKeys` |

`Event.Data` is excluded by default. Selecting a key exports its
`fmt.Sprint` value and does not redact it. Do not select arguments, results,
credentials, or other sensitive fields without a separate redaction policy.

The event span inherits the parent span from the context passed to `Emit`. Each
span represents one emitted event, not the duration of a complete run.

## Validation

- `conformance.CheckEventSink` verifies that a sink accepts a well-formed event.
- The OTel adapter tests cover span naming, attributes, data exclusion,
  allowlisting, and parent-trace inheritance.
- These checks do not prove delivery, retention, or backend access control.
