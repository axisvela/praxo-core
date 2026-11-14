# Structured Output

This example validates a final JSON answer against a schema and rejects invalid
output.

```bash
g++ -std=c++20 -I language/cpp/include language/cpp/examples/structured-output/main.cpp \
  language/cpp/build/libpraxo_cpp.a -o build/cpp-structured-output
./build/cpp-structured-output
```

Expected output:

```text
C++ structured output example passed
```
