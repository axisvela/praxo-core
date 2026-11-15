# COBOL Consumer

This example runs a deterministic model against the COBOL Core, registers one
`record(target)` tool, applies an explicit tool scope plus policy, and checks
that an allowed call produces one effect while a denied call produces none.

```bash
python language/cobol/examples/consumer/build.py
```

Set `COBC` if GnuCOBOL is not on `PATH`.

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
