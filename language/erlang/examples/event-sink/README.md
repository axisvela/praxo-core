# Event Sink

This example uses the Erlang Core sink composition to fan out lifecycle and tool
events and filter the tool-only stream.

After `erlc` has populated `language/erlang/build/ebin`:

```bash
escript language/erlang/examples/event-sink/event_sink.escript
```

Expected output:

```text
Erlang event sink example passed
```
