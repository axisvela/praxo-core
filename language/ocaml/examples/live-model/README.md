# OCaml Live Model

This example wires the OCaml Core OpenAI-compatible adapter (`openai_model`) to
`PRAXO_BASE_URL`, registers a low-risk `get_time` tool, and restricts the run to
`get_time` with a policy hook.

## Run

From the repository root:

```bash
ocaml unix.cma language/ocaml/examples/live-model/live_model.ml
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

## Transport Seam

The OCaml Core keeps a dependency-free build and does not bundle an HTTP client.
`openai_model` takes a caller-supplied `transport` value. This example therefore
defines a placeholder transport that fails with:

```text
live model run failed: Failure("no HTTP transport is configured for POST ...")
Check PRAXO_BASE_URL (...), PRAXO_MODEL (...), and PRAXO_API_KEY
```

It is a transport-seam example, not a fully runnable live client. To run it
against a real endpoint, replace `transport` in `live_model.ml` with a function
that performs the request, for example over `Unix` sockets for HTTP or a
third-party TLS client for HTTPS, and returns:

```ocaml
{ http_status = 200; http_body = "..." }
```

## Core limits

The OCaml `tool` record exposes only a name, description, and invoke function,
and the policy hook receives only the action kind. The example uses
`agent_allowed_tools = ["get_time"]` for the tool-name check and a policy that
allows `model.generate` and `tool.invoke`; other action kinds are denied. The
adapter does not send a per-tool JSON Schema parameter object.

Identity, durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
