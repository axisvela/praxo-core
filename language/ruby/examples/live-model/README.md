# Ruby Live Model

This source-mode example connects the Ruby Core to an OpenAI-compatible endpoint
and registers one low-risk `get_time` tool.

## Run

```bash
ruby -I language/ruby/lib language/ruby/examples/live-model/live_starter.rb
```

Or install the gem and run it from this directory:

```bash
gem install praxo-core
ruby live_starter.rb
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
