# Streaming

This example collects agent stream parts from the C++ Core and checks the
`values` and `messages` lifecycle.

```bash
g++ -std=c++20 -I language/cpp/include language/cpp/examples/streaming/main.cpp \
  language/cpp/build/libpraxo_cpp.a -o build/cpp-streaming
./build/cpp-streaming
```

Expected output:

```text
C++ streaming example passed
```
