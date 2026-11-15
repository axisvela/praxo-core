# Delphi / Free Pascal Consumer

This example uses the source Delphi/Free Pascal Core with a deterministic host,
one registered `record` tool, an explicit tool scope, and a policy that permits
only the `public` target. It does not use a network or a live model.

Run from the repository root:

```bash
mkdir -p build/delphi
fpc -Mobjfpc -Facwstring -Fulanguage/delphi -FEbuild/delphi language/delphi/examples/consumer/consumer.pas
./build/delphi/consumer
```

On Windows use `build\delphi\consumer.exe`.

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The allowed call invokes the tool once. The denied call is rejected before
`Invoke`, so the in-memory counter stays at zero. The example prints a failure
line and exits nonzero when either check does not hold.

The Core policy hook exposes the action kind only, so this example binds the
requested target to the run before the tool decision. It verifies a deterministic
allow/deny path only and does not prove live-model quality, authentic identity,
durable approvals, isolation, or effect reconciliation.
