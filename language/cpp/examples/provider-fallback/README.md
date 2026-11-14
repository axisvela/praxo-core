# Provider Fallback

This example calls a fallback only after the primary fails and preserves the
primary error when both fail.

```bash
g++ -std=c++20 language/cpp/examples/provider-fallback/main.cpp \
  -o build/cpp-fallback
./build/cpp-fallback
```

Expected output:

```text
C++ provider fallback example passed
```
