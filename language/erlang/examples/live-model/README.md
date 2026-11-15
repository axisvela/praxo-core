# Erlang Live Model

This example connects the Erlang Core to an OpenAI-compatible endpoint through
`praxo_openai_compatible` and registers one low-risk `get_time(zone)` tool. The
model may only call `get_time`; every other tool call is denied by policy.

Compile the runtime first, then run:

```bash
python language/erlang/run-tests.py
escript language/erlang/examples/live-model/live_model.escript
```

Environment variables:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=qwen3.5:4b
# export PRAXO_API_KEY=...   # only for hosted endpoints
export PRAXO_PROMPT="What time is it? Use get_time with zone set to utc and reply with the time."
```

PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
$env:PRAXO_PROMPT = "What time is it? Use get_time with zone set to utc and reply with the time."
```

The adapter uses the OTP `httpc` client, so this example is fully runnable
against a reachable endpoint; it needs no injected transport. Hosted HTTPS
endpoints require normal OTP TLS configuration. On failure the example prints
troubleshooting for `PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY` and
exits nonzero.

The example authorizes only `get_time`; every other tool call is denied by
policy. It is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
