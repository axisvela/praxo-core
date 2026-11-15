# C Live Model

This example connects the C Core to an OpenAI-compatible endpoint through the
existing `px_openai_generate` adapter and registers one low-risk `get_time(zone)`
tool. The model may only call `get_time`; every other tool call is denied by
policy.

## Run

From the C CMake build directory:

```bash
cmake -S language/c -B language/c/build
cmake --build language/c/build
./language/c/build/praxo-c-live-model-example
```

Or compile the source directly:

```bash
gcc -std=c11 -I language/c/include -I language/c/src \
  language/c/examples/live-model/main.c \
  language/c/build/libpraxo_core.a -o build/c-live-model
./build/c-live-model
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

The C Core bundles no HTTP client. `px_openai_generate` requires a caller-owned
`PxOpenAITransport`:

```c
const char *transport(const char *url, const char *body,
    const char *api_key, void *ctx, const char **error);
```

Return the response body on success with `*error == NULL`, or set `*error` and
return `NULL`. The example ships `missing_transport`, which reports
`PROVIDER_HTTP`; replace the `state.adapter.transport` assignment in `main` with
a transport built on your HTTP library (for example libcurl). Without it the
example prints troubleshooting for `PRAXO_BASE_URL`, `PRAXO_MODEL`, and
`PRAXO_API_KEY` and exits nonzero.

The example authorizes only `get_time`; every other tool call is denied by
policy. It is an integration starting point, not a production security profile.
Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
