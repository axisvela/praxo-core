# Elixir Live Model

This source-mode example connects the Elixir Core to an OpenAI-compatible
endpoint and registers one low-risk `get_time` tool.

## Run

```bash
elixir -pa language/elixir/build/ebin language/elixir/examples/live-model/live_starter.exs
```

Build the Core first if `language/elixir/build/ebin` is empty:

```bash
mkdir -p language/elixir/build/ebin
elixirc -o language/elixir/build/ebin language/elixir/lib/praxo/*.ex language/elixir/lib/praxo/adapters/*.ex
```

Environment:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=qwen3.5:4b
# export PRAXO_API_KEY=...   # only for hosted endpoints
```

PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
```

The example authorizes only `get_time`; every other tool call is denied by
policy. It is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
