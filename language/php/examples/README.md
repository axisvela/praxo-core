# PHP Examples

- [`consumer/`](consumer/): published Packagist
  `axisvela/praxo-core:0.4.1` starter with deterministic allow/deny checks.

- [`event-sink/`](event-sink/): lifecycle and tool events through `MultiSink`
  and `FilterSink`, with a deterministic check.
- [`retry/`](retry/): retry transient model failures with model middleware and
  a deterministic check.
- [`checkpoint/`](checkpoint/): checkpoint allowlist round trip and
  unregistered-type rejection.

The consumer example installs a published package. The other examples use the
source SDK when run from this repository.
