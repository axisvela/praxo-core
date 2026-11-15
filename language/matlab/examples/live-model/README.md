# MATLAB/Octave Live Model

This example connects the shared MATLAB/Octave Core to an OpenAI-compatible
endpoint through `praxo.openai_compatible`, registers a `get_time(zone)` tool
with a small JSON Schema, and restricts the run to `get_time`.

## Run

From the repository root:

```bash
octave-cli --path language/matlab-octave-core \
  --path language/matlab/examples/live-model --eval live_model_example
```

Environment:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
# $env:PRAXO_API_KEY = "..."   # only for hosted endpoints
# $env:PRAXO_PROMPT = "What time is it? Use get_time with zone set to utc and reply with the time."
```

On POSIX use the equivalent `export` commands.

The shared Core does not bundle an HTTP client, so this example supplies a
caller-owned transport. It posts the JSON payload with `curl` and returns a
`struct('status', ..., 'body', ...)` to `praxo.openai_compatible`. `curl` must
be on `PATH`. The transport works in both MATLAB and Octave, where the built-in
`webwrite` path is MATLAB-specific and does not send a raw JSON body in Octave.

The shared agent loop restricts the advertised and permitted tool names with
`toolSelection`. The example authorizes only `get_time`; every other tool call
fails before invocation. It is an integration starting point, not a production
security profile. Identity, durable approvals, isolation, and effect
reconciliation remain the application's responsibility.

## Shared with Octave

MATLAB and Octave use the implementation in `language/matlab-octave-core/+praxo`.
The Octave entry point reuses this example through
`language/octave/examples/live-model/run.m`.
