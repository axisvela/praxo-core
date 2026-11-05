# PRAXO-CORE for GNU Octave

Native Octave Core for the PRAXO-CORE agent framework. This package is the
independent Octave implementation with source tag `octave/v0.2.1`. It passes all
eleven shared vector groups under GNU Octave 11.3.0 and includes the native agent
loop, memory store, checkpoint allowlist, lexical path policy, context
compaction, event sinks, middleware helpers, and tool selection. It does not
delegate behavior to Go or another language Core.

MATLAB is a separate Core target in `language/matlab`; Octave package
publication does not claim MATLAB runtime verification.

## Install

```octave
pkg install https://github.com/axisvela/praxo-core/releases/download/octave/v0.2.1/praxo-core-0.2.1.tar.gz
pkg load praxo-core
```

After the Octave Packages entry is merged:

```octave
pkg install -forge praxo-core
pkg load praxo-core
```

## Run the Checks

With Python 3.10+ and an Octave CLI available, from the repository root:

```bash
python language/octave/run-tests.py
python language/octave/api-snapshot.py --check
```

Set `OCTAVE` or pass `--octave /path/to/octave-cli` to select the interpreter.
Python only launches the native tests and checks the source API inventory. The
implementation and tests run in Octave, not Python. The runner covers all eleven
shared vector groups and verifies each fixture's group and `SPEC_VERSION` before
running it.

The Octave package archive is built with:

```bash
python language/octave/build_octave_package.py
```

It contains `DESCRIPTION`, `inst/+praxo`, `LICENSE`, and `README.md`.

## API

```matlab
node = praxo.parse_json('{"name":"echo","input":{"text":"hi"}}');
raw = praxo.encode_json(node);
call = praxo.parse_tool_call(raw);
paths = praxo.validate_schema(praxo.parse_json('{"type":"string"}'), node);
[valid, manifest] = praxo.validate_manifest('{}');
result = praxo.agent_run('hello', @(request) struct('content', 'hello'), {}, struct());
```

JSON nodes have `kind` and `value` fields. Objects use an N-by-2 cell array of
original keys and typed values; arrays use cells; `null` is a distinct kind.
This avoids host JSON decoders conflating null, empty arrays, and singleton
arrays or rewriting object keys. JSON strings are represented as UTF-8 bytes
in character vectors.

## Agent Loop

`praxo.agent_run(prompt, model, tools, options)` accepts a character-vector
prompt, a model function handle, a cell array of tool structs, and an options
struct. The model receives a struct with `messages` and `tools` cell arrays and
returns a struct with character-vector `content`, optional `toolCalls` cell
array, and optional nonnegative integer `inputTokens` and `outputTokens`.
Each call has character-vector `id` and `name`, and `arguments` as a typed JSON
object node. Each tool has a unique `name`, optional `description`, and an
`invoke` function handle receiving the arguments node and returning a JSON node.
The tool result is JSON-encoded and added to subsequent model messages with its
`toolCallId`. Calls run sequentially. Callback exceptions fail the run.

Options `maxSteps` and `maxTokens` default to 8 and 0 respectively; zero tokens
means unlimited, and steps must be positive. The result contains `output`,
`steps`, token counts, ordered event names, `toolInvocations`, `messages`,
`errorCode`, and `errorMessage`. An empty `errorCode` indicates success.
Budget failures use `AGENT_MAX_STEPS` or `AGENT_MAX_TOKENS`; missing tools use
`TOOL_NOT_FOUND`, while invalid or failing model and tool callbacks use local
`MODEL_ERROR` and `TOOL_ERROR`. Invalid configuration raises `praxo:agent`.

## Current Limits

- Numbers are finite double-precision values; large integers and decimal
  spellings may lose precision.
- JSON input and output are bounded to 1,048,576 characters and nesting to 64.
  The tool-call helpers reject inputs over 262,144 characters.
- Tool calls cover canonical JSON, XML-style, dotted tags and plain dotted
  lines. Other reference formats such as DSML, invoke, todo and skill-install
  are not implemented. Parsed governance metadata is returned under `metadata`;
  generated call IDs are not provided.
- Schema patterns accept a limited anchored ASCII subset, not full RE2.
  Unsupported patterns fail explicitly with `praxo:schema`.
- Manifest validation rejects duplicate and unknown fields and validates
  declarations. It does not verify signatures, establish trust, execute
  plugins, or enforce OS sandboxing.
- Core-local errors are not new shared wire error codes. Passing all eleven
  vector groups does not imply full Framework or Go feature parity.

The source is MIT; see [LICENSE](LICENSE). Octave is a separate GPL-licensed
interpreter and test tool, not a package dependency or copied code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/octave.md), and
[implementation support](../../docs/languages/support.md).
