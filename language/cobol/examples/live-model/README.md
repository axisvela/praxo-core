# COBOL Live Model

This example connects the COBOL Core to an OpenAI-compatible endpoint through
the existing `praxo-openai` transport-seam adapter and registers one low-risk
`get_time(zone)` tool. The model may only call `get_time`; every other tool call
is denied by policy.

## Build and run

```bash
python language/cobol/examples/live-model/build.py
./language/cobol/build/live-model-example
```

Set `COBC` if GnuCOBOL is not on `PATH`.

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

The COBOL Core bundles no HTTP client. `praxo-openai` calls the program named by
`px-provider-transport-program` with a `px-provider-call` record containing the
URL, request payload, optional API key, and response fields. The caller must:

- perform the HTTP POST and fill `px-provider-response` and
  `px-provider-response-length`;
- set `px-provider-status-code` to the HTTP status;
- leave `px-status` empty on success or set an error code.

The example ships `live-transport`, which reports `PROVIDER_HTTP`. Replace it
with a program built on your HTTP client (for example a C binding or a helper
process). Without it the example prints troubleshooting for `PRAXO_BASE_URL`,
`PRAXO_MODEL`, and `PRAXO_API_KEY` and exits nonzero.

`get_time` uses GnuCOBOL `FUNCTION CURRENT-DATE`, the host wall clock. The
`utc` branch adds a `Z` suffix; run on a UTC host if you need strict UTC. The
example authorizes only `get_time`; every other tool call is denied by policy.
It is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
