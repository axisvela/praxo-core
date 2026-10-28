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

## Go Finalization Order

In the unreleased Go source, a final answer passes `AfterRun` middleware,
including structured-output validation and repair, before `OnRunComplete`, the
`checkpoint` projection, memory write, and `run.completed`, in that order.
Validation or repair failure does not publish a final checkpoint, save the
answer, or send completion. Raw model messages and text deltas remain provisional
and may already have been streamed before final validation.

`OnRunComplete` receives a copy of the validated result. It may reject completion
by returning an error, but changes to that copy do not rewrite the final result,
run identity, checkpoint projection, or memory record. Use `AfterRun` middleware
for intentional output transformations before finalization.

A completion hook, checkpoint callback, or memory error prevents the completion
notification and follows the run-failure path. If the `run.completed` sink itself
returns an error, `Run` returns that error and invokes `OnRunError`, but does not
attempt `run.failed`: a fail-fast sink may already have delivered completion to
some consumers. Thus a completion notification alone does not guarantee that
`Run` returned nil. A non-nil error must always be checked, even if a result is
also returned.

These callbacks and writes do not form an atomic transaction. A checkpoint
projection can precede a failing memory write, and a successful memory write is
not rolled back when event delivery fails. The checkpoint stream part is a final
result projection, not proof of durable checkpoint storage or exactly-once
execution. Consumers must provide their own transactional persistence where
required. Earlier source tags retain their original callback ordering; other
SDKs require separate lifecycle verification.

Entered middleware is finalized even when a later `BeforeRun` callback fails.
Only the entered prefix, including the rejecting callback, receives `AfterRun`;
startup rejection still emits no run events. An `AfterRun` error does not stop
later cleanup callbacks, which receive the original execution error or the first
finalization error. The first error remains primary. Ordinary callback panics
still propagate; cleanup is not guaranteed to continue after an `AfterRun` panic.
Built-in call limits and tool selection use an internal run identity to release
their state even when no `Result` exists.

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
