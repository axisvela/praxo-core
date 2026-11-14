# Event Sink

This example uses Zig Core sink composition to fan out events and filter the
tool-only stream.

```bash
zig build-exe language/zig/examples/event-sink/event_sink.zig \
  --dep models --dep runtime \
  -Mroot=language/zig/examples/event-sink/event_sink.zig \
  -Mmodels=language/zig/src/models.zig -Mruntime=language/zig/src/runtime.zig \
  -femit-bin=build/zig-event-sink
./build/zig-event-sink
```

Expected output:

```text
Zig event sink example passed
```
