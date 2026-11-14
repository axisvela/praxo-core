# Elixir HITL Approval

This example demonstrates a write tool that requires human approval:

- approve the original `write_note(text="hello", visibility="public")` call;
- edit the decision to `visibility="private"`, which is reauthorized and denied
  before the tool runs.

```bash
elixir -pa language/elixir/build/ebin language/elixir/examples/hitl/hitl.exs
```

Expected output:

```text
approve: written; effects=1
edit: policy rejected; effects=0
```
