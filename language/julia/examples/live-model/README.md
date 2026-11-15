# Julia Live Model

This example connects the Julia Core to an OpenAI-compatible endpoint through
`openai_compatible`, registers a `get_time(zone)` tool with a small JSON Schema,
and restricts the run to `get_time`.

## Run

From the repository root, install the declared `JSON` dependency once:

```bash
julia --project=language/julia -e 'using Pkg; Pkg.instantiate()'
```

Then run:

```bash
julia --project=language/julia language/julia/examples/live-model/live_starter.jl
```

Environment:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
# $env:PRAXO_API_KEY = "..."   # only for hosted endpoints
# $env:PRAXO_PROMPT = "What time is it? Use get_time with zone set to utc and reply with the time."
```

On POSIX use the equivalent `export` commands.

The adapter uses the `JSON` package already declared by the Julia package and
its default transport invokes `curl`. `curl` must be available on `PATH`, or a
caller-owned `transport = (path, payload) -> decoded_json` can be supplied.

The example authorizes only `get_time`; every other tool call is denied by
`allowed_tools` and the policy. Tool registration calls
`PraxoCore.AgentRuntime.register!` directly because the `ToolRegistry` method is
not currently exported through the `PraxoCore` shorthand. It is an integration
starting point, not a production security profile. Identity, durable approvals,
isolation, and effect reconciliation remain the application's responsibility.
