# COBOL Provider Transport Scaffold

This scaffold wires `praxo-openai` and a `get_time(zone)` tool, but **does not
connect to a model out of the box**. The shipped `live-transport` stub returns
`PROVIDER_HTTP` without making a request. Setting an endpoint, model, and key
does not replace the stub. For a runnable, offline allow/deny check, start with
the [deterministic consumer](../consumer/).

## Build and run

```bash
python language/cobol/examples/live-model/build.py
./language/cobol/build/live-model-example
```

Set `COBC` if GnuCOBOL is not on `PATH`.

After supplying a real transport, configure it with these environment variables:

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

The callback is synchronous. Set connection and response deadlines inside the
transport; Core's cooperative cancellation cannot interrupt a blocked callback.
Keep this example out of per-record batch and online transaction paths. The
[batch exception review example](../batch-exception-review/) demonstrates a
separate review step without requiring a live model.

`get_time` uses GnuCOBOL `FUNCTION CURRENT-DATE`, the host wall clock. The
`utc` branch adds a `Z` suffix; run on a UTC host if you need strict UTC. The
example authorizes only `get_time`; every other tool call is denied by policy.
It is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
