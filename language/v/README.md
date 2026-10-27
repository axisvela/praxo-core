# PRAXO-CORE for V

V is a native Core implementation targeting the PRAXO-CORE contract. It
passes all eleven shared vector groups with `V 0.5.2` and includes the native
agent loop, context compaction, memory store, path policy, checkpoint
allowlist, and tool-call parsing. PII, structured output, call limit, and tool
selection are standalone helpers, not integrated agent middleware. Vector
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

## Current Limits

- Verified with `V 0.5.2` and the bundled `tcc` on Windows. Other V releases,
  `gcc`, and remote CI are not yet verified.
- JSON is decoded with `x.json2`. Invalid JSON and trailing data are rejected;
  duplicate object keys are not a declared vector and should not be treated as
  a security boundary.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. Generated call IDs are not provided. Markup stripping is not an
  authorization control or sanitizer.
- Schema patterns use the V `regex` module. Unsupported patterns are reported
  as schema errors rather than silently accepted.
- Path checks are lexical and confined by separator boundaries. They do not
  resolve symlinks or replace operating-system sandboxing.
- Provider adapters, streaming wire encodings, and plugin hosts are not part of
  this SDK.
- Concrete built-in model modes, including fallback, cannot directly accept a
  consumer-supplied provider.

The source is MIT; see [LICENSE](LICENSE). V and its bundled toolchain are
separate projects, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/v.md), and
[implementation support](../../docs/languages/support.md).
