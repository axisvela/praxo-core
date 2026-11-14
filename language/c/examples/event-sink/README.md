# Event Sink

This example uses the C Core sink composition to fan out lifecycle and tool
events and filter the tool-only stream.

```bash
gcc -std=c11 -I language/c/include language/c/examples/event-sink/main.c \
  language/c/build/libpraxo_core.a -o build/c-event-sink
./build/c-event-sink
```

Expected output:

```text
C event sink example passed
```
