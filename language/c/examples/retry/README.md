# Retry

This example retries a transient failure with a bounded attempt count and
preserves the final error when attempts are exhausted.

```bash
gcc -std=c11 language/c/examples/retry/main.c -o build/c-retry
./build/c-retry
```

Expected output:

```text
C retry example passed
```
