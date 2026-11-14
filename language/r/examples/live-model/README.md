# R Live Model

This example connects the R Core to an OpenAI-compatible endpoint and registers
one low-risk `get_time` tool.

## Run

```bash
cd language/r/examples/live-model
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=qwen3.5:4b
# export PRAXO_API_KEY=...   # only for hosted endpoints
Rscript live.R
```

PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
Rscript live.R
```

The R adapter is non-streaming. It posts to `{base_url}/chat/completions`,
authorizes only `get_time`, and prints the model response.

The example is an integration starting point, not a production security
profile. Identity, durable approvals, isolation, and effect reconciliation
remain the application's responsibility.
