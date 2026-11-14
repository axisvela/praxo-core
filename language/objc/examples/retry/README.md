# Retry

This example retries a transient failure with a bounded attempt count and keeps
the exhausted failure state.

```bash
clang -x objective-c language/objc/examples/retry/retry.m -o build/objc-retry
./build/objc-retry
```

Expected output:

```text
Objective-C retry example passed
```
