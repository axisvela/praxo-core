# Nim Live Model

This example connects the Nim Core to an OpenAI-compatible endpoint through
`newOpenAICompatible`, registers a `get_time(zone)` tool with a small JSON
Schema, and restricts the run to `get_time`.

## Run

From the repository root:

```bash
nim r --path:language/nim/src language/nim/examples/live-model/live_starter.nim
```

Environment:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
# $env:PRAXO_API_KEY = "..."   # only for hosted endpoints
# $env:PRAXO_PROMPT = "What time is it? Use get_time with zone set to utc and reply with the time."
```

On POSIX use the equivalent `export` commands.

The adapter uses `std/httpclient` from the Nim standard library, so no extra
package is required.

Current adapter limitation: `OpenAICompatible` advertises every tool with the
generic `{"type":"object"}` parameters object and does not yet forward a
per-tool JSON Schema. This example keeps the `get_time` schema and validates
the incoming arguments against it, but the model sees the generic parameters
object. The tool name and description still guide tool selection.

The example authorizes only `get_time`; every other tool call is denied by
`allowedTools` and the policy. It is an integration starting point, not a
production security profile. Identity, durable approvals, isolation, and effect
reconciliation remain the application's responsibility.
