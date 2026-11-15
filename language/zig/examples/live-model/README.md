# Zig Live Model

This example connects the Zig Core OpenAI-compatible adapter to an
OpenAI-compatible endpoint and registers one low-risk `get_time` tool.

## Run

From the repository root:

```bash
mkdir -p build
zig build-exe language/zig/examples/live-model/live_model.zig \
  --dep agent --dep json --dep models --dep openaicompat \
  -Mroot=language/zig/examples/live-model/live_model.zig \
  -Magent=language/zig/src/agent.zig \
  -Mjson=language/zig/src/json.zig \
  -Mmodels=language/zig/src/models.zig \
  -Mopenaicompat=language/zig/src/openaicompat.zig \
  -femit-bin=build/zig-live-model
./build/zig-live-model
```

On Windows use `build\zig-live-model.exe`.

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

The Zig adapter uses the standard-library `std.http` transport, so this example
is fully runnable without extra packages.

The Zig `Registry` advertises each tool from its name and description only; it
does not carry a per-tool parameter schema, so the adapter sends an empty object
as the tool parameters. The `zone` argument is described in the tool
description. The example authorizes only `get_time`; every other tool call is
denied by policy. It is an integration starting point, not a production security
profile. Identity, durable approvals, isolation, and effect reconciliation
remain the application's responsibility.
