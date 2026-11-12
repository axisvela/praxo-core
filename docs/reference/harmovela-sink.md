# Harmovela Event Sink

This is the shared mapping for a native Harmovela event sink. It is an optional
adapter contract, not a new Core wire state machine or a delivery guarantee.

## Endpoint

`POST {baseURL}/events` with `content-type: application/json`.

`baseURL` normally ends in `/aep/api`; the Go adapter uses
`http://127.0.0.1:8790/aep/api` as its local example.

## Envelope

```json
{
  "spec_version": "0.2",
  "id": "run-123-1700000000000000000",
  "type": "tool.call",
  "source": "praxo-core",
  "created_at": "2026-11-10T07:00:00.000000000Z",
  "payload": {
    "session_id": "s1",
    "run_id": "run-123",
    "name": "echo"
  }
}
```

- `spec_version` defaults to `0.2`.
- `id` is derived from the run id, else the session id, plus a nanosecond
  timestamp. It is an identifier, not proof of exactly-once delivery.
- `type` is the Core event type unchanged.
- `source` defaults to `praxo-core`.
- `created_at` is UTC RFC 3339 with nanoseconds.
- `payload` is the event data plus `session_id` and `run_id` when present.

## Sink Behavior

- A 2xx response is success; any other status is an error containing the status
  and a bounded response body.
- The sink does not add authentication. Put it behind a trusted network
  boundary or a product-owned authenticated gateway.
- Event data may contain sensitive content. Apply caller-side filtering before
  the sink.
- Use HTTPS for remote endpoints.
- The sink does not provide retries, buffering, acknowledgements, ordering, or
  exactly-once delivery. Those remain integration responsibilities.

## Baseline Status

The canonical per-language list is the [adapter status](../languages/adapter-status.md#harmovela)
table. Native sinks cover Go, Python, TypeScript, Java, Rust, C#, R, Elixir,
Ruby, PHP, Lua, Nim, Perl, Erlang, Julia, V, D, Dart, Swift, Delphi/Free Pascal,
Objective-C, MATLAB, GNU Octave, and Zig. Haskell, OCaml, C, C++, and Fortran
provide caller-supplied transport seams; PowerShell inherits the C# Core.
COBOL and other implementations do not have a sink. Each implementation uses an
injected transport or loopback fixture in tests; no live Harmovela service is
claimed.

## Testing

Use an injected transport or a loopback HTTP fixture. Required assertions:
request path, envelope fields, payload merging, 2xx success, and non-2xx error.
Do not use a live Harmovela service as the only test.
