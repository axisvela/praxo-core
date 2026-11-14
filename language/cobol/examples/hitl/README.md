# COBOL HITL Approval

This example demonstrates a write tool that requires human approval:

- approve the original `write_note(text="hello", visibility="public")` call;
- edit the decision to `visibility="private"`, which is reauthorized and denied
  before the tool runs.

```bash
python language/cobol/examples/hitl/build.py
```

Expected output:

```text
approve: written; effects=1
edit: policy rejected; effects=0
```

The policy denial surfaces as `POLICY_ERROR` through the COBOL agent callback.
