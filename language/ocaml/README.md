# PRAXO-CORE for OCaml

Unreleased native Wire-stage candidate targeting a Framework implementation.
The current code has no agent loop, model provider, process bridge, or plugin
host. It does not call Go or another language SDK.

Local validation uses OCaml 4.14.2 in bytecode mode. Native compilation, remote
CI, package-registry publication, commercial support, production readiness, and
a delivery date are not claimed. A Linux CI job is configured but has not run.

## Build and Test

With OCaml and Python 3.10 or newer, from the repository root:

```bash
python language/ocaml/run-tests.py
python language/ocaml/api-snapshot.py --check
```

Set `OCAMLC` or pass `--compiler /path/to/ocamlc`. The runner also needs
`ocamlrun` from the same distribution. Python only launches the native compiler,
runtime, and API checks; the implementation and tests are OCaml.

To build manually from `language/ocaml/`:

```bash
ocamlc -c praxo.mli
ocamlc -c praxo.ml
ocamlc -c praxo_tests.ml
ocamlc -o build/praxo_tests praxo.cmo praxo_tests.cmo
ocamlrun build/praxo_tests ../../spec
```

## API

```ocaml
let node = Praxo.parse_json "{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}"
let raw = Praxo.encode_json node
let _call = Praxo.parse_tool_call raw
let _paths = Praxo.validate_schema (Praxo.parse_json "{\"type\":\"string\"}") node
let _manifest = Praxo.validate_manifest "{}"
```

Public declarations are inventoried in [`api/unreleased.txt`](api/unreleased.txt).
`validate_manifest` returns `Some manifest` only for a valid declaration.

## Current Limits

- The verified target is OCaml 4.14.2 bytecode on Windows. Native OCaml, other
  versions, Linux CI, and macOS are not yet verified.
- JSON input and output are bounded to 1,048,576 characters and nesting to 64.
  Tool-call input is bounded to 262,144 characters.
- JSON strings are UTF-8 and accept surrogate escapes; the encoder escapes
  control characters. Numbers are finite IEEE doubles, so large integers and
  exact decimal spellings may lose precision. Nonfinite values, invalid UTF-8,
  malformed escapes, and trailing JSON are rejected.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. DSML, invoke, todo, and skill-install formats are not implemented.
  Generated call IDs are not provided. Markup stripping is not an authorization
  control or security sanitizer.
- Schema patterns accept a bounded anchored ASCII subset, not full RE2.
  Unsupported patterns raise `Schema_error`. JSON Schema behavior follows the
  documented subset, including zero bounds treated as unset and ignored unknown
  keywords.
- Manifest checks validate declarations only. They do not verify signatures,
  establish trust, execute plugins, or enforce OS sandboxing. Duplicate fields
  are rejected as a local hardening rule.
- SDK-local exceptions are not new shared wire error codes. Passing three vector
  groups does not imply full Framework or Go feature parity.

The source is MIT; see [LICENSE](LICENSE). OCaml and its runtime are separate
toolchain components, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/ocaml.md), and
[implementation support](../../docs/languages/support.md).
