# Independent Rust Consumer

This starter installs the published crates.io package `praxo-core@0.8.0` and
verifies an allow/deny governed tool path.

```bash
cd language/rust/examples/consumer
cargo run
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The starter uses a deterministic model. It does not prove live provider behavior,
authentic identity, durable approvals, or production readiness.
