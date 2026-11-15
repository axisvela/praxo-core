# Fortran Live Model

This example connects the Fortran Core to an OpenAI-compatible endpoint through
the existing `praxo_openai` adapter and registers one low-risk `get_time(zone)`
tool. The model may only call `get_time`; every other tool call is denied by
policy.

Build the pinned RE2 bridge once with
`python language/fortran/run-tests.py --re2-only`, then build:

```bash
python language/fortran/examples/live-model/run.py
```

Run with the transport supplied:

```bash
PRAXO_RUN_LIVE=1 python language/fortran/examples/live-model/run.py
# or
./language/fortran/build/live-model-example/live_model_example
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

## Transport seam

The Fortran Core bundles no HTTP client. `openai_compatible%transport` is a
procedure pointer with this signature:

```fortran
function transport(url, payload, api_key, error) result(body)
  character(*), intent(in) :: url, payload, api_key
  type(sdk_error), intent(out) :: error
  character(:), allocatable :: body
end function
```

Return the response body with an empty `error%code`, or set the error and return
an empty body. The example ships `missing_transport`, which reports
`PROVIDER_HTTP`; assign a transport built on your HTTP library in
`live-model_example.f90`. Without it the example prints troubleshooting for
`PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY` and exits nonzero.

## Schema limitation

`praxo_types::tool_spec` currently carries only `name` and `description`, and
`praxo_openai` emits `"parameters":{"type":"object"}` for every tool. The
`get_time(zone)` tool is registered with that schema shape; adding a per-tool
JSON Schema requires an additive Core API change.

`get_time` uses `DATE_AND_TIME`, the host wall clock. The `utc` branch adds a
`Z` suffix; run on a UTC host if you need strict UTC. The example authorizes
only `get_time`; every other tool call is denied by policy. It is an integration
starting point, not a production security profile. Identity, durable approvals,
isolation, and effect reconciliation remain the application's responsibility.
