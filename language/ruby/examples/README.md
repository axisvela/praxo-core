# Ruby Examples

- [`consumer/`](consumer/): published RubyGems `praxo-core==0.7.0` starter with
  deterministic allow/deny checks.

- [`event-sink/`](event-sink/): lifecycle and tool events through `MultiSink`
  and `FilterSink`, with a deterministic check.
- [`retry/`](retry/): retry transient model failures with a bounded model
  wrapper and a deterministic check.
- [`checkpoint/`](checkpoint/): checkpoint allowlist round trip and
  unregistered-type rejection.

The consumer example installs a published gem. The other examples use the source
SDK when run from this repository.
