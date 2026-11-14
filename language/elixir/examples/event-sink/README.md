# Event Sink

This example uses the Elixir Core sink composition to fan out lifecycle and tool
events and filter the tool-only stream.

After `elixirc` has populated `language/elixir/build/ebin`:

```bash
elixir -pa language/elixir/build/ebin language/elixir/examples/event-sink/event_sink.exs
```

Expected output:

```text
Elixir event sink example passed
```
