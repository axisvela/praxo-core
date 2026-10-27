# PRAXO-CORE for MATLAB and Octave

Unreleased native Wire-stage candidate targeting a Framework implementation.
The current code has no agent loop, model provider, process bridge, or plugin
host. It does not delegate its behavior to Go or another language SDK.

Local validation uses GNU Octave 11.3.0; MATLAB compatibility is a target, not
yet independently verified. No MATLAB release, package-registry publication,
production-readiness claim, or delivery date is implied.

## Run the Checks

With Python 3.10+ and an Octave CLI available, from the repository root:

```bash
python language/matlab/run-tests.py
python language/matlab/api-snapshot.py --check
```

Set `OCTAVE` or pass `--octave /path/to/octave-cli` to select the interpreter.
Python only launches the native tests and checks the source API inventory.
The implementation and tests run in Octave, not Python. The three shared vector
groups are `toolcall`, `jsonschema`, and `plugin`; the test runner verifies the
fixture group and `SPEC_VERSION` before running them.

## API

Add `language/matlab` to the interpreter path and call:

```matlab
node = praxo.parse_json('{"name":"echo","input":{"text":"hi"}}');
raw = praxo.encode_json(node);
call = praxo.parse_tool_call(raw);
paths = praxo.validate_schema(praxo.parse_json('{"type":"string"}'), node);
[valid, manifest] = praxo.validate_manifest('{}');
```

JSON nodes have `kind` and `value` fields. Objects use an N-by-2 cell array of
original keys and typed values; arrays use cells; `null` is a distinct kind.
This avoids host JSON decoders conflating null, empty arrays, and singleton
arrays or rewriting object keys. JSON strings are represented as UTF-8 bytes
in character vectors; MATLAB's character model has not yet been validated.

## Current Limits

- Numbers are finite double-precision values; large integers and decimal
  spellings may lose precision. Do not use these codecs for values requiring
  exact numeric preservation. Invalid UTF-8, malformed escapes, trailing data,
  and nonfinite numbers are rejected.
- JSON input and output are bounded to 1,048,576 characters and nesting to 64.
  The tool-call helpers reject inputs over 262,144 characters.
- Tool calls cover canonical JSON, XML-style, dotted tags and plain dotted
  lines. Other reference formats such as DSML, invoke, todo and skill-install
  are not implemented. Parsed governance metadata is returned under `metadata`;
  generated call IDs are not provided. Markup stripping is not an authorization
  control or security sanitizer.
- Schema patterns accept a limited anchored ASCII subset, not full RE2.
  Unsupported patterns fail explicitly with `praxo:schema`; pattern input is
  bounded. Unknown JSON Schema keywords follow the documented subset behavior.
- Manifest validation rejects duplicate and unknown fields and validates
  declarations. It does not verify signatures, establish trust, execute
  plugins, or enforce OS sandboxing. Duplicate-field rejection is stricter than
  the Go JSON decoder.
- SDK-local errors are not new shared wire error codes. Neither passing three
  vector groups nor an Octave test implies full Framework or Go feature parity.

The source is MIT; see [LICENSE](LICENSE). Octave is a separate GPL-licensed
interpreter and test tool, not a package dependency or code copied into this
implementation. MATLAB is a separate proprietary runtime.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/matlab.md), and
[implementation support](../../docs/languages/support.md).
