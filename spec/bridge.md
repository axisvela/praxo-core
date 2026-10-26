# Bridge Contract

**Status:** draft for Shell and PowerShell; `SPEC_VERSION` `0.2.0`.
**Implementation:** Go bridge CLI (`cmd/praxo-bridge`), planned.

Bridge languages must not reimplement the agent loop. They call a maintained
runtime through a small process boundary.

## Process Contract

```text
praxo-bridge <command> [subcommand]
```

- Input: one JSON object on stdin.
- Output: one JSON object on stdout.
- Diagnostics: stderr only.
- Exit code: `0` success, `1` contract error, `2` usage error.
- No credentials in argv. Use environment variables or a config file.
- The bridge declares `SPEC_VERSION` in `version`.

## Commands

### `version`

Input: `{}`

Output:

```json
{"sdkVersion":"0.1.0","specVersion":"0.2.0"}
```

### `toolcall parse`

Input:

```json
{"content":"{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}"}
```

Output:

```json
{"call":{"name":"echo","input":{"text":"hi"}}}
```

No call:

```json
{"call":null}
```

### `toolcall strip`

Input:

```json
{"content":"hello<tool_call name=\"echo\">{}</tool_call>world"}
```

Output:

```json
{"text":"helloworld"}
```

### `jsonschema validate`

Input:

```json
{"schema":{"type":"object"},"data":{}}
```

Output:

```json
{"valid":true,"errorPaths":[]}
```

### `tool list`

Input: `{}`

Output:

```json
{"tools":[]}
```

The bridge does not host tool plugins yet. A bridge run uses no tools.

### `run`

Input:

```json
{"prompt":"hello","sessionId":"s1","maxSteps":8}
```

Model configuration comes from the environment, never argv:

- `PRAXO_BASE_URL` (required)
- `PRAXO_API_KEY` (optional)
- `PRAXO_MODEL` (optional)
- `PRAXO_MAX_STEPS` (optional, default 8)

Output:

```json
{
  "runId":"run-...",
  "output":"...",
  "steps":1,
  "usage":{"inputTokens":1,"outputTokens":2,"cachedTokens":0}
}
```

### `event stream`

Input is the same as `run`. Output is JSON Lines: each event object is written
as one line, followed by a final result line:

```json
{"type":"run.started","sessionId":"s1","runId":"run-..."}
{"type":"run.completed","sessionId":"s1","runId":"run-..."}
{"type":"result","result":{"runId":"run-...","output":"...","steps":1}}
```

When the caller does not supply a streaming emitter, the same data is returned
as one object with `events` and `result` keys.

### `plugin validate`

Input, one of:

```json
{"raw":"{...manifest json...}"}
{"manifest":{"schemaVersion":1}}
```

Success:

```json
{"valid":true,"id":"com.example.echo","kind":"tool.provider.v1"}
```

Failure:

```json
{"valid":false,"error":{"code":"PLUGIN_INVALID_MANIFEST","message":"..."}}
```

## Errors

Contract errors use the shared error codes from `spec/wire/errors.json`.
Errors that do not map to a contract code use:

- `BRIDGE_USAGE`
- `BRIDGE_IO`
- `BRIDGE_JSON`

Envelope:

```json
{"error":{"code":"BRIDGE_JSON","message":"..."}}
```

## Streaming

Future event and run commands use JSON Lines: one JSON object per line on
stdout. `stderr` is diagnostic only. Do not mix logs into stdout.

## Security

- Do not pass API keys as command-line arguments.
- Do not log tenant identifiers or credentials.
- Do not let a bridge rewrite policy decisions or tool-call markup.
- Treat the process boundary as untrusted input; validate JSON before use.

## Shell and PowerShell Wrappers

Wrappers may add argument parsing and file I/O, but must:

- preserve stdout JSON and stderr diagnostics,
- propagate exit codes,
- avoid shell interpolation of untrusted JSON,
- document the supported `SPEC_VERSION`.

## Related Documents

- [Language expansion plan](../docs/contributing/language-policy.md)
- [Language support matrix](languages.md)
- [Event schema](../docs/reference/events.md)
- [Plugin authoring](../docs/guides/plugins.md)
