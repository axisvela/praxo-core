# Haskell HITL Approval

This example demonstrates a write tool that requires human approval:

- approve the original `write_note(text="hello", visibility="public")` call;
- edit the decision to `visibility="private"`, which is reauthorized and denied
  before the tool runs.

Run from the repository root:

```bash
runghc -ilanguage/haskell/src -ilanguage/haskell/examples/hitl language/haskell/examples/hitl/starter.hs
```

Expected output:

```text
approve: written; effects=1
edit: policy rejected; effects=0
```

Run the deterministic example test:

```bash
runghc -ilanguage/haskell/src -ilanguage/haskell/examples/hitl language/haskell/examples/hitl/test_starter.hs
```

Expected output:

```text
Haskell HITL example test passed
```

The model is a deterministic fixture so the approval path is reproducible. To
use a live model, replace `generateFixture` with the OpenAI-compatible adapter
and prompt the model to call `write_note` with `text` and `visibility`.

The example is an integration starting point, not a production approval store.
Durable approvals, identity, and effect reconciliation remain the application's
responsibility.
