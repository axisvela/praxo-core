# D Live Model

This example connects the D Core to an OpenAI-compatible endpoint through
`OpenAICompatibleModel` and registers one low-risk `get_time` tool with a small
JSON Schema. The policy allows only `model.generate` and the `get_time`
`tool.invoke`; the tool scope is `["get_time"]`.

## Run

From the repository root:

```bash
dmd -i -Ilanguage/d/source -run language/d/examples/live-model/live_model.d
```

Environment:

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
# $env:PRAXO_API_KEY = "..."   # only for hosted endpoints
```

The default `OpenAICompatibleModel` transport invokes `curl` with
`POST {PRAXO_BASE_URL}/chat/completions`. Install `curl` or inject a
`ProviderTransport` for a different HTTP client. A failed request prints
troubleshooting for the base URL, model, and API key and exits nonzero.

This is an integration starting point, not a production security profile.
