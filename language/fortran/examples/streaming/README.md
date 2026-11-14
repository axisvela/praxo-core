# Streaming

This example collects agent stream parts from the Fortran Core and checks the
`values` and `messages` lifecycle.

Build the pinned RE2 bridge once, then build and run the example:

```bash
python language/fortran/run-tests.py --re2-only
python language/fortran/examples/streaming/run.py
```

Expected output:

```text
Fortran streaming example passed
```
