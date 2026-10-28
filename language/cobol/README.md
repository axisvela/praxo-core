# COBOL Core

A native GnuCOBOL implementation, not a bridge to another Core. All 63 normative
vectors across the eleven groups pass, together with native agent, JSON,
contract-boundary, tooling, and API declaration checks. The
`cobol-conformance` remote job passes; `cobol/v0.1.0` is the released Core implementation tag.

## Build and Test

Use GnuCOBOL 2.0 or later and Python 3.10 or later:

```sh
python language/cobol/run-tests.py
```

Set `COBC` or pass `--compiler /path/to/cobc` when the compiler is not on PATH.
The driver builds one combined COBOL source per suite to avoid an old
GnuCOBOL multi-file code-generation issue. Generated files stay in
`language/cobol/build/`. Python only generates and launches native tests; it is not
required by a compiled Core consumer.

## Native API

| Program | Purpose |
| --- | --- |
| `praxo-run` | Agent loop with model, tool dispatcher, policy, and event callbacks |
| `praxo-checkpoint` | Registered payload-type JSON envelopes |
| `praxo-context` | Token estimate and context compaction |
| `praxo-event` | Filter and multi-sink event delivery |
| `praxo-jsonschema` | Object/array schema validation |
| `praxo-schema-scalar` | Internal scalar schema checks |
| `praxo-schema-visit` | Internal recursive object/array checks |
| `praxo-memory` | In-memory session records and search |
| `praxo-middleware` | Call limits, tool selection, fallback, structured output, email redaction |
| `praxo-path-normalize` | Lexical path normalization |
| `praxo-pattern-check` | Bounded ASCII pattern matcher |
| `praxo-plugin` | Strict manifest parsing and validation |
| `praxo-policy` | Lexical path grants |
| `praxo-stream` | Stream-kind constants |
| `praxo-toolcall` | JSON, XML-style, dotted-tag, and plain tool-call parsing |
| `praxo-json-parse`, `praxo-json-generate`, `praxo-json-string`, `praxo-json-quote`, `praxo-json-slice`, `praxo-utf8` | Native JSON and UTF-8 utilities |

Records are declared in `language/cobol/copy/`. The agent callback interface is:

```cobol
call "praxo-run" using px-options px-session px-prompt
    px-result px-user-data
```

`px-options` names the model, tool dispatcher, policy, and event programs.
`px-user-data` is a caller-owned 4096-byte callback context. Blank callback
status means success; model/tool statuses propagate; a nonblank policy status
denies the action. The input session is not mutated, and each run uses local
history. Zero or negative `px-max-steps` selects eight steps; a nonpositive
token budget is unlimited.

## Scope and Limits

The agent API is wire-shaped but not a full Go model surface: it carries text
messages, one tool-call list per response, and callback events. It does not
carry full assistant tool-call history, stream parts, event session/run IDs, or
provider adapters. The event and stream programs exercise the contract behavior
but are not asynchronous runtimes.

JSON inputs are limited to 32768 bytes, 512 nodes, and 64 nested containers.
Strings preserve trailing spaces and embedded NUL bytes. Invalid UTF-8, lone
surrogates, malformed numbers, and trailing data are rejected. Duplicate object
keys are retained; lookup uses the last value. Generated JSON is limited to
16384 bytes. JSON utilities return local `JSON_INVALID` and `JSON_CAPACITY`
statuses, not new wire error codes.

Checkpoint allowlists wrap JSON values only; they do not instantiate arbitrary
native types. Plugin parsing validates the top-level and entrypoint field sets,
required launch targets, protocol, isolation, capabilities (including
non-adjacent duplicates), and basic identity/version syntax. It does not yet
execute plugins, verify signatures, or fully validate permissions, limits,
health, SBOM, and signature contents.

Schema validation covers the vector-defined object, array, string, number,
integer, boolean, enum, length, pattern, and numeric-bound behavior. Numeric
bounds use finite floating-point conversion, so very large integers are not
arbitrary precision. Patterns are a bounded ASCII subset: literals, dot,
classes/ranges, anchors, and `*`, `+`, `?`. Groups, alternation, counted
repetition, Unicode pattern matching, and unsupported escapes return
`SCHEMA_PATTERN_UNSUPPORTED` instead of accepting data.

Path policy is lexical normalization, not OS confinement. It rejects UNC,
drive-relative, and traversal-outside-root paths in the exercised cases but
does not resolve symlinks, reparse points, filesystem case rules, or races. Do
not use it as a sandbox. Email redaction covers only email addresses, not other
PII classes. Memory search uses ASCII case folding and lexical ordering of
canonical UTC timestamps.

## Gates

`api/unreleased.txt` inventories public copybook records, module program IDs,
and linkage parameters. `api-snapshot.py --check` runs in the test driver;
regenerate intentionally with `--update`. Tooling tests check fixture
determinism, assertion polarity, and snapshot sensitivity. The
`cobol-conformance` CI job runs all of these plus the two original native test
programs.

`cobol/v0.1.0` is the released source tag. `api/unreleased.txt` is the legacy
filename for the 0.1.0 declaration snapshot; later changes require a new
version/tag decision and release review. `spec/parity/cobol.md` records partial
surfaces. The Core sources are MIT-licensed; GnuCOBOL and its runtime are
separately licensed external toolchain dependencies.
