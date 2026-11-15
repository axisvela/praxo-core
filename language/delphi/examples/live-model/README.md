# Delphi / Free Pascal Live Model

This example connects the Delphi/Free Pascal Core to an OpenAI-compatible
endpoint through `TPraxoOpenAIAdapter` and registers one low-risk `get_time` tool
with a small JSON Schema. The policy allows only `model.generate` and the
`get_time` `tool.invoke`; the tool scope is `["get_time"]`.

## Run

From the repository root:

```bash
mkdir -p build/delphi
fpc -Mobjfpc -Facwstring -Fulanguage/delphi -FEbuild/delphi language/delphi/examples/live-model/live_model.pas
./build/delphi/live_model
```

On Windows use `build\delphi\live_model.exe`.

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

The adapter uses core `fphttpclient`, so no provider SDK is needed. To use a
caller-owned HTTP client, inject the `Transport` callback on
`TPraxoOpenAIAdapter`. A failed request prints troubleshooting for the base URL,
model, and API key and exits nonzero.

This is an integration starting point, not a production security profile.
