# Fortran HITL Approval

This example demonstrates a write tool that requires human approval:

- approve the original `write_note(text="hello", visibility="public")` call;
- edit the decision to `visibility="private"`, which is reauthorized and denied
  before the tool runs.

Build the pinned RE2 bridge once with
`python language/fortran/run-tests.py --re2-only`, then run:

```bash
python language/fortran/examples/hitl/run.py
```

Expected output:

```text
approve: written; effects=1
edit: policy rejected; effects=0
```
