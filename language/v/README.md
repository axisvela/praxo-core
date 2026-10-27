# PRAXO-CORE for V

V is a native Core implementation with source tag `v/v0.1.0`. It passes all
eleven shared vector groups with `V 0.5.2` and includes the native
agent loop, context compaction, memory store, path policy, checkpoint
allowlist, and tool-call parsing. Tool selection, PII redaction, structured
output, and call limits are opt-in in the agent. Vector
coverage does not establish full Core parity or production readiness.

The SDK does not call Go or another language runtime. It has no provider
adapter or plugin host; those remain outside the declared Core scope.

## Build And Test

From the repository root with V and a C compiler on `PATH`:

```bash
python language/v/api-snapshot.py --check
v -cc tcc -gc none -o build/praxo-v-conformance language/v/conformance/run.v
./build/praxo-v-conformance
v -cc tcc -gc none -o build/praxo-v-tests language/v/tests/run.v
./build/praxo-v-tests
```

On Windows use `build\praxo-v-conformance.exe` and
`build\praxo-v-tests.exe`. The `-path` flag is not needed: the compiler
resolves `import praxo` from the language tree.

The complete local environment procedure, including manual V installation,
is in [SETUP.md](SETUP.md).

## API

```v
import praxo

call := praxo.parse_tool_call('<tool_call name="echo">{"text":"hi"}</tool_call>') or {
	panic(err)
}
assert call.name == 'echo'

schema := praxo.parse_json('{"type":"string","pattern":"^a+$"}') or { panic(err) }
assert praxo.validate_schema(schema, praxo.parse_json('"aaa"') or { panic(err) }).len == 0
```

Public declarations are inventoried in [`api/0.1.0.txt`](api/0.1.0.txt).

Supply a model callback to receive each request and return a response or an
error. The callback can inspect the conversation and tool results on each step;
callback-backed models also work with `fallback_model`.

Set `options.tool_selection = praxo.tool_selection(['echo'])` to advertise and
allow only the named tools. An empty selection denies all tools. Without a
selection, all configured tools remain available. A request for an unselected
tool fails with `AGENT_TOOL_NOT_SELECTED` before the tool is invoked.

Set `options.pii_redaction = true` to redact the existing email, SSN,
credit-card, and US-style phone patterns in model-bound message content and text blocks, and in
tool results recursively. This does not redact tool arguments, events, final
output, block image/data fields, or arbitrary PII; it is not a complete privacy
boundary. The original session messages are not modified.

Set `options.structured_output = praxo.structured_output(schema, max_repairs, repairer)`
to validate the final output with the existing schema helper. A successful repair
becomes the output; invalid output fails with `AGENT_STRUCTURED_OUTPUT`.
Set `options.model_call_limit` and `options.tool_call_limit` to positive values
to bound calls per run. Nonpositive values are unlimited. The next invocation
is blocked with `AGENT_MODEL_CALL_LIMIT` or `AGENT_TOOL_CALL_LIMIT`; counters
are independent for each run. All these options are disabled by default.

```v
fn generate(req praxo.Request) !praxo.Response {
    return praxo.response(praxo.message_assistant('Hello', []praxo.ToolCall{}), praxo.usage(0, 0))
}

options := praxo.agent_options(praxo.callback_model(generate))
result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'Hi') or { panic(err) }
```

## Current Limits

- Verified with `V 0.5.2` and the bundled `tcc` on Windows. Other V releases,
  `gcc`, and remote CI are not yet verified.
- JSON is decoded with `x.json2`. Invalid JSON and trailing data are rejected;
  duplicate object keys are not a declared vector and should not be treated as
  a security boundary.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. Generated call IDs are not provided. Markup stripping is not an
  authorization control or sanitizer.
- Run IDs combine nanosecond time with a random suffix. They are not a
  guaranteed global identifier.
- Schema patterns use the V `regex` module. Unsupported patterns are reported
  as schema errors rather than silently accepted.
- Path checks are lexical and confined by separator boundaries. They do not
  resolve symlinks or replace operating-system sandboxing.
- Provider adapters, streaming wire encodings, and plugin hosts are not part of
  this SDK.

The source is MIT; see [LICENSE](LICENSE). V and its bundled toolchain are
separate projects, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/v.md), and
[implementation support](../../docs/languages/support.md).
