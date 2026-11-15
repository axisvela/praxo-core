# C Consumer

This example runs a deterministic model against the C Core, registers one
`record(target)` tool, applies an explicit tool scope plus policy, and checks
that an allowed call produces one effect while a denied call produces none.

Build from the C CMake build directory, then run `praxo-c-consumer-example`.
From the repository root with a prebuilt static library:

```bash
cmake -S language/c -B language/c/build
cmake --build language/c/build
./language/c/build/praxo-c-consumer-example
```

Or compile the source directly:

```bash
gcc -std=c11 -I language/c/include language/c/examples/consumer/main.c \
  language/c/build/libpraxo_core.a -o build/c-consumer
./build/c-consumer
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
