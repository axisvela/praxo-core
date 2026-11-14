# Checkpoint Allowlist

This example uses the Elixir Core checkpoint allowlist to encode and decode only
registered payload types.

After `elixirc` has populated `language/elixir/build/ebin`:

```bash
elixir -pa language/elixir/build/ebin language/elixir/examples/checkpoint/checkpoint.exs
```

Expected output:

```text
Elixir checkpoint example passed
```

The example covers a registered round trip and rejection of an unregistered
type with `CHECKPOINT_TYPE_NOT_ALLOWED`.
