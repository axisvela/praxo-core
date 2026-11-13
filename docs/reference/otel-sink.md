# OpenTelemetry Event Sink

This is the shared mapping for a native OpenTelemetry event sink. It is an
optional adapter contract, not a new Core wire state machine, sampler, collector,
or delivery guarantee.

## Boundary

- Each Core event maps to one OTLP span named `praxo.<event.type>`.
- The sink may use an OpenTelemetry SDK or emit OTLP/HTTP JSON through a
  caller-supplied transport. The Core does not require the OpenTelemetry SDK.
- Event data is excluded by default. A caller may allowlist individual keys.
- Session and run identifiers are exported when present; use opaque identifiers
  and restrict access to the telemetry backend.

## OTLP/HTTP JSON

`POST {endpoint}` with `content-type: application/json`. A typical endpoint is
`http://127.0.0.1:4318/v1/traces`.

```json
{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "praxo-core"}}
        ]
      },
      "scopeSpans": [
        {
          "scope": {"name": "praxo-core"},
          "spans": [
            {
              "traceId": "0123456789abcdef0123456789abcdef",
              "spanId": "0123456789abcdef",
              "name": "praxo.tool.call",
              "kind": 1,
              "startTimeUnixNano": "1794294000000000000",
              "endTimeUnixNano": "1794294000000000000",
              "attributes": [
                {"key": "praxo.event.type", "value": {"stringValue": "tool.call"}},
                {"key": "praxo.session.id", "value": {"stringValue": "s1"}},
                {"key": "praxo.run.id", "value": {"stringValue": "run-123"}},
                {"key": "praxo.event.at", "value": {"stringValue": "2026-11-10T07:00:00Z"}}
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

- Identifiers are hexadecimal strings: 16 bytes for `traceId`, 8 bytes for
  `spanId`.
- `startTimeUnixNano` and `endTimeUnixNano` are Unix nanoseconds. One span
  represents one event, not the duration of a complete run.
- Empty session/run identifiers and zero timestamps are omitted.
- Allowed data keys become `praxo.event.data.<key>` string attributes. Selecting
  a key does not redact its value.

## Transport Seam

Implementations without the OpenTelemetry SDK may accept a caller-supplied
transport with the HTTP request method, URL, headers, and body. The transport
returns a status code and a bounded response body. A 2xx status is success; any
other status is an error containing the status and a bounded body.

## Baseline Status

The canonical per-language list is the
[adapter status](../languages/adapter-status.md#opentelemetry) table. Go maps
events through `adapters/otel` and a `trace.Tracer`. Python, TypeScript, Java,
Rust, R, C#, Ruby, PHP, Elixir, Lua, and C provide transport-seam sinks over a
caller-supplied OTLP/HTTP transport. Other implementations do not have an
in-tree OTel sink yet. All
current implementations use deterministic fixtures or an in-memory exporter in
tests; no live collector, sampling policy, or vendor backend is claimed.

## Testing

Use an in-memory exporter or an injected transport. Required assertions: span
name, trace/span identifier shape, start and end timestamps, session/run
attributes, default data exclusion, explicit allowlist behavior, 2xx success,
and non-2xx error.
