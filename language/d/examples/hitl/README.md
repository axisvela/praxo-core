# D HITL Approval

This example demonstrates a write tool that requires human approval:

- approve the original `write_note(text="hello", visibility="public")` call;
- edit the decision to `visibility="private"`, which is reauthorized and denied
  before the tool runs.

Run from the repository root:

```bash
dmd -i -Ilanguage/d/source -run language/d/examples/hitl/starter.d
```

Expected output:

```text
approve: written; effects=1
edit: policy rejected; effects=0
```

Run the deterministic example test:

```bash
dmd -i -Ilanguage/d/source -Ilanguage/d/examples/hitl -version=HitlExampleTest -run language/d/examples/hitl/test_starter.d
```

Expected output:

```text
D HITL example test passed
```

The model is a deterministic fixture so the approval path is reproducible. To
use a live model, replace `FixtureModel` with `OpenAICompatibleModel` and prompt
the model to call `write_note` with `text` and `visibility`.

The example is an integration starting point, not a production approval store.
Durable approvals, identity, and effect reconciliation remain the application's
responsibility.
