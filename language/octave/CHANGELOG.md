# Changelog

## 0.5.0 - 2026-11-13

- Add an OpenTelemetry OTLP/HTTP sink over a caller-supplied transport with an
  explicit data allowlist, deterministic trace and span IDs, and bounded
  `OTEL_HTTP` errors.
- Add a document and function-handle retriever seam with query and limit
  validation.
- Add a synchronous subagent request/result/task seam with terminal states and
  error-code preservation.
