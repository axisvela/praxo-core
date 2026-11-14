# Event Sink

This example uses the C++ Core sink composition to fan out lifecycle and tool
events and filter the tool-only stream.

```bash
g++ -std=c++20 -I language/cpp/include language/cpp/examples/event-sink/main.cpp \
  language/cpp/build/libpraxo_cpp.a -o build/cpp-event-sink
./build/cpp-event-sink
```

Expected output:

```text
C++ event sink example passed
```
