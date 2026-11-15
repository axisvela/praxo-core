# C++ Consumer

This example runs a deterministic model against the C++ Core, registers one
`record(target)` tool, applies an explicit tool scope plus policy, and checks
that an allowed call produces one effect while a denied call produces none.

Build from the C++ CMake build directory, then run
`praxo-cpp-consumer-example`. Or compile directly:

```bash
g++ -std=c++20 -I language/cpp/include language/cpp/examples/consumer/main.cpp \
  language/cpp/build/libpraxo_cpp.a -o build/cpp-consumer
./build/cpp-consumer
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
