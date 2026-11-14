# Retry

This example retries a transient failure with a bounded attempt count and
rethrows the final error when attempts are exhausted.

```bash
g++ -std=c++20 language/cpp/examples/retry/main.cpp -o build/cpp-retry
./build/cpp-retry
```

Expected output:

```text
C++ retry example passed
```
