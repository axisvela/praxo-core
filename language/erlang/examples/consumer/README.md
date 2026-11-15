# Erlang Consumer

This example runs a deterministic model against the Erlang Core, registers one
`record(target)` tool, applies an explicit tool scope plus policy, and checks
that an allowed call produces one effect while a denied call produces none.

Compile the runtime first, then run:

```bash
python language/erlang/run-tests.py
escript language/erlang/examples/consumer/consumer.escript
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The fixture model requests a tool. The tool scope names only `record`, and the
policy accepts only `target == "public"`. The denied path must leave the
in-memory effect counter at zero. A mismatch crashes the escript with a nonzero
exit status. No network, credentials, or model service are used. This does not
prove live-model quality, authentic identity, isolation, or durable effects.
