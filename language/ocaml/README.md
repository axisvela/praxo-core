# PRAXO-CORE for OCaml

Native Core implementation with source tag `ocaml/v0.2.0`. It passes all eleven
vector groups on OCaml 4.14.2 bytecode and includes the native agent loop, memory
store, checkpoint allowlist, lexical path policy, context compaction, event
sinks, middleware helpers, and tool selection. It does not call Go or another
language Core; there is no provider adapter, process bridge, or plugin host.

The experimental path check is lexical and does not resolve symlinks or reparse
points; it must not be used as an OS containment boundary. The loop does not
persist session history and its run IDs can collide. Callback exceptions trigger
a best-effort `run.failed` notification before the original exception is
re-raised; notification failure does not replace it. Do not treat the loop as
production-ready.

Local validation uses OCaml 4.14.2 in bytecode mode, and the Linux CI job runs
the same full suite. Native `ocamlopt` compilation, package-registry
publication, commercial support, production readiness, and a delivery date are
not claimed. The source tag does not imply package-registry publication.

## Build and Test

With OCaml and Python 3.10 or newer, from the repository root:

```bash
python language/ocaml/run-tests.py
python language/ocaml/api-snapshot.py --check
```

Set `OCAMLC` or pass `--compiler /path/to/ocamlc`. The runner also needs
`ocamlrun` from the same distribution. Python only launches the native compiler,
runtime, and API checks; the implementation and tests are OCaml.
See [SETUP.md](SETUP.md) for the tested toolchain configuration and commands.

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

Public declarations are inventoried in [`api/0.2.0.txt`](api/0.2.0.txt).
`validate_manifest` returns `Some manifest` only for a valid declaration.

## Current Limits

- The verified target is OCaml 4.14.2 bytecode. Native `ocamlopt`, other
  versions, and macOS are not yet verified.
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
- Core-local exceptions are not new shared wire error codes. Passing all eleven
  vector groups does not imply full Framework or Go feature parity.

The source is MIT; see [LICENSE](LICENSE). OCaml and its runtime are separate
toolchain components, not vendored code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/ocaml.md), and
[implementation support](../../docs/languages/support.md).
