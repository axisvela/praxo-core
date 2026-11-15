# V Live Model

This example connects the V Core OpenAI-compatible adapter to an
OpenAI-compatible endpoint and registers one low-risk `get_time` tool.

## Run

From the repository root:

```bash
v -path "language/v|@vlib|@vmodules" language/v/examples/live-model/live_model.v
```

Environment:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=qwen3.5:4b
# export PRAXO_API_KEY=...   # only for hosted endpoints
export PRAXO_PROMPT="What time is it? Use get_time with zone set to utc."
```

PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
```

The run prints `result.output`. On failure it prints troubleshooting for
`PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY` and exits nonzero.

The V adapter uses the built-in `net.http` transport, so this example is fully
runnable without extra packages.

The V `Tool` type exposes a name, description, and invoke function. It does not
carry a per-tool parameter schema, so the adapter sends an empty object as the
tool parameters; the `zone` argument is described in the tool description. The
explicit tool scope limits the run to `get_time`; the policy allows
`model.generate` and `tool.invoke` and denies other action kinds. It is an
integration starting point, not a production security profile. Identity,
durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
