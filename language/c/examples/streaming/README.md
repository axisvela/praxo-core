# Streaming

This example forwards model deltas through the C Core `on_delta` callback and
checks that the deltas reconstruct the final output.

```bash
gcc -std=c11 -I language/c/include language/c/examples/streaming/main.c \
  language/c/build/libpraxo_core.a -o build/c-streaming
./build/c-streaming
```

Expected output:

```text
C streaming example passed
```
