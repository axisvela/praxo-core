# Octave Live Model

Octave reuses the shared MATLAB/Octave example at
`language/matlab/examples/live-model/live_model_example.m`. The `run.m` wrapper
adds the shared Core and example paths, then runs the same
OpenAI-compatible `get_time` flow.

From the repository root:

```bash
octave-cli language/octave/examples/live-model/run.m
```

Environment:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
# $env:PRAXO_API_KEY = "..."   # only for hosted endpoints
# $env:PRAXO_PROMPT = "What time is it? Use get_time with zone set to utc and reply with the time."
```

On POSIX use the equivalent `export` commands.

The shared example supplies a caller-owned transport that posts the JSON
payload with `curl` and returns `struct('status', ..., 'body', ...)` to
`praxo.openai_compatible`. `curl` must be on `PATH`. This works in Octave, where
the built-in `webwrite` path does not send a raw JSON body. The example prints
troubleshooting for the base URL, model, and API key on failure.

See [`../../../matlab/examples/live-model/README.md`](../../../matlab/examples/live-model/README.md)
for the shared adapter and scope notes.
