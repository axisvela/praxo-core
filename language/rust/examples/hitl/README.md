# Rust HITL Approval

This example uses published crates.io `praxo-core@0.8.0` to demonstrate a write
tool that requires human approval:

- approve the original `write_note(text="hello", visibility="public")` call;
- edit the decision to `visibility="private"`, which is reauthorized and denied
  before the tool runs.

```bash
cd language/rust/examples/hitl
cargo run
```

Expected output:

```text
approve: written; effects=1
edit: policy rejected; effects=0
```
