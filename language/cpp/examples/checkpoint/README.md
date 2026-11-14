# Checkpoint Allowlist

This example uses the C++ Core checkpoint allowlist to encode and decode only
registered payload types.

```bash
g++ -std=c++20 -I language/cpp/include language/cpp/examples/checkpoint/main.cpp \
  language/cpp/build/libpraxo_cpp.a -o build/cpp-checkpoint
./build/cpp-checkpoint
```

Expected output:

```text
C++ checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
