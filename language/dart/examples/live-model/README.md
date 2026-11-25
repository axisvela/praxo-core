# Dart Live Model

This example connects the Dart Core to an OpenAI-compatible endpoint through
`OpenAICompatibleModel` and registers one low-risk `get_time` tool with a small
JSON Schema. The policy allows only `model.generate` and the `get_time`
`tool.invoke`; the tool scope is `["get_time"]`.

## Run

From the repository root:

```bash
dart language/dart/examples/live-model/live_model.dart
```

Or from `language/dart`:

```bash
dart run language/go/examples/live-model/live_model.dart
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

The synchronous `OpenAICompatibleModel.generate` transport supports plain
`http` by default. For `https`, inject a caller-owned `transport` or use
`generateAsync`; the Core agent loop uses the synchronous path. A failed request
prints troubleshooting for the base URL, model, and API key and exits nonzero.

This is an integration starting point, not a production security profile.
