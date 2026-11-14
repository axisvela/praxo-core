# Event Sink

This example uses Objective-C Core sink composition to fan out events and filter
the tool-only stream.

```bash
clang -fobjc-arc -Ilanguage/objc \
  language/objc/examples/event-sink/event_sink.m language/objc/PraxoCore.m \
  language/objc/PraxoJSON.m -framework Foundation -o build/objc-event-sink
./build/objc-event-sink
```

Expected output:

```text
Objective-C event sink example passed
```
