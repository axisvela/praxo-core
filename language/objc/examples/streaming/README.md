# Streaming

This example accumulates streamed chunks and checks that they reconstruct the
final output.

```bash
clang -x objective-c language/objc/examples/streaming/streaming.m \
  -o build/objc-streaming
./build/objc-streaming
```

Expected output:

```text
Objective-C streaming example passed
```
