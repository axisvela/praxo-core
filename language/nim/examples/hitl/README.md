# Nim HITL Approval

This example demonstrates a write tool that requires human approval:

- approve the original `write_note(text="hello", visibility="public")` call;
- edit the decision to `visibility="private"`, which is reauthorized and denied
  before the tool runs.

```bash
nim r --path:language/nim/src language/nim/examples/hitl/starter.nim
```

Expected output:

```text
approve: written; effects=1
edit: policy rejected; effects=0
```

Run the deterministic self-check with:

```bash
nim r --path:language/nim/src language/nim/examples/hitl/test_starter.nim
```

Expected output:

```text
Nim HITL example test passed
```

The model is a deterministic fixture so the approval path is reproducible. The
agent has an explicit tool scope and an argument-aware policy. The edited
`visibility="private"` arguments are reauthorized and denied with
`AGENT_POLICY_DENIED` before the effect counter changes. To use a live model,
replace `fixtureModel` with `openaiModel(newOpenAICompatible(...))` and prompt
the model to call `write_note` with `text` and `visibility`.

The example is an integration starting point, not a production approval store.
Durable approvals, identity, and effect reconciliation remain the application's
responsibility.
