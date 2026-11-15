# Fortran Consumer

This example runs a deterministic model against the Fortran Core, registers one
`record(target)` tool, applies an explicit tool scope plus policy, and checks
that an allowed call produces one effect while a denied call produces none.

Build the pinned RE2 bridge once with
`python language/fortran/run-tests.py --re2-only`, then run:

```bash
python language/fortran/examples/consumer/run.py
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The fixture model requests a tool. The tool scope names only `record`, and the
policy accepts only `target == "public"`. The denied path must leave the
in-memory effect counter at zero. No network, credentials, or model service are
used. This does not prove live-model quality, authentic identity, isolation, or
durable effects.
