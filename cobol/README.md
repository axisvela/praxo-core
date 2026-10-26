# COBOL Core SDK Work in Progress

This is an unreleased, native GnuCOBOL implementation, not a bridge to another
SDK. It is not yet a conforming Core SDK. The full 11 vector groups, API
snapshot, parity inventory, and release gates are still pending.

## Build and Test

Use GnuCOBOL 2.0 or later and its C toolchain:

```sh
python cobol/run-tests.py
```

Set `COBC` or pass `--compiler /path/to/cobc` when the compiler is not on PATH.
Python only builds and launches the native tests; no Python code is used at
runtime. Generated executables go in `cobol/build/`.

## Native Agent

`copy/api.cpy` declares the records for `praxo-run`:

```cobol
call "praxo-run" using px-options px-session px-prompt
    px-result px-user-data
```

Callback program names are configured in `px-options`. All arguments are passed
by reference. `px-user-data` is a caller-owned 4096-byte context shared by the
callbacks. A blank status means success; nonblank model/tool statuses propagate
to `px-result-error`. A nonblank policy status denies the action. Event callbacks
are best effort and do not determine run success.

| Callback | Arguments |
| --- | --- |
| Model | session, response, user-data, status |
| Tool dispatcher | call, tool-result, user-data, status |
| Policy | action, user-data, status |
| Event sink | event, user-data, status |

The input session is not mutated. Each run uses local storage. Zero or negative
`px-max-steps` selects eight steps; a nonpositive token budget is unlimited.
There are explicit limits of 64 messages, eight tool calls per response, and
2048 bytes per text/argument value. Lengths preserve trailing spaces. Invalid
lengths and counts fail rather than indexing outside a record.

This initial API does not yet represent full assistant tool-call history,
session/run event identifiers, streaming, or the remaining Core subsystems.
It is experimental and may change before the first release.

## JSON

The JSON routines are written in COBOL without third-party parser code. They do
not assume the existence of runtime programs named `json-parse` or `json-emit`.

| Program | Arguments | Behavior |
| --- | --- | --- |
| `praxo-json-parse` | input, document, error | Parse exactly one JSON value |
| `praxo-json-generate` | document, output, error | Serialize the node tree |
| `praxo-json-string` | input, cursor, string, error | Decode a quoted string and advance the 1-based cursor |
| `praxo-json-quote` | string, output, error | Escape and quote a UTF-8 string |
| `praxo-utf8` | string, error | Validate UTF-8 |

Records are in `copy/json.cpy`. Nodes are in preorder with 1-based parent
indices; the root parent is zero. Kinds are object `O`, array `A`, key `K`,
string `S`, number `N`, true `T`, false `F`, and null `Z`. Object keys precede
their values and share their parent. Strings are decoded UTF-8; numbers retain
their lexical representation. Duplicate keys are preserved, not resolved.

Limits are 32768 input bytes, 512 nodes, 64 nested containers, 2048 decoded
bytes per string/number, and 16384 generated output bytes. Overflow returns
`JSON_CAPACITY`; malformed JSON or UTF-8 returns `JSON_INVALID`. Failed parsing
clears the node count, and failed generation clears the output. These are local
utility statuses, not additions to the framework wire error contract.

## License

The SDK sources are original MIT-licensed code under the repository license.
GnuCOBOL and its runtime remain separately licensed build/runtime dependencies;
their license and redistribution obligations are not replaced by MIT.
