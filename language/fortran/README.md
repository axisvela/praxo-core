# Fortran Core SDK

A native Fortran 2008 implementation with source tag `fortran/v0.2.0`. This is
not a bridge to Go, C, Python, or another SDK. All 62 normative vectors across
eleven groups pass locally, alongside native regression tests and the API
declaration snapshot. The tag is a source release, not package-registry
publication. Documented limitations remain below.

## Build and Test

Use GNU Fortran and Python 3.10 or later:

```sh
python language/fortran/run-tests.py
```

See [SETUP.md](SETUP.md) for the recorded environment, configuration, test
commands, and local results.

Set `FC` or pass `--compiler /path/to/gfortran` if needed. The driver compiles
with Fortran 2008 mode, warnings as errors, and runtime checks. Generated
modules and executables are confined to `language/fortran/build/`.

Python is only a build/test dependency. `conformance.py` translates the declared
JSON fixtures into Fortran test inputs and assertions; every behavior under test
runs in the compiled Fortran SDK. The generator verifies the complete vector
group inventory and rejects unknown operations rather than silently skipping
them. Python is not required by a compiled SDK consumer.

## API

| Module | Surface |
| --- | --- |
| `praxo_types` | Messages, calls, requests, responses, usage, sessions, events, decisions, results, errors |
| `praxo_interfaces` | Abstract model, tool, policy, and event sink; tool registry |
| `praxo_agent` | Agent options and bounded agent loop |
| `praxo_context` | Token estimate and context compaction |
| `praxo_runtime` | Recording, filter, and multi event sinks; in-memory store |
| `praxo_unicode`, `praxo_json` | Native UTF-8, JSON parsing, encoding, traversal, and equality |
| `praxo_checkpoint` | Registered-type JSON envelopes |
| `praxo_toolcall` | JSON, XML-style, dotted-tag, and plain tool-call parsing; markup removal |
| `praxo_schema`, `praxo_pattern` | Contract schema validation and bounded ASCII patterns |
| `praxo_policy` | Lexical path grants |
| `praxo_plugin` | Strict manifest parsing and validation |
| `praxo_middleware` | Per-run limits, tool selection, fallback, structured-output repair, PII redaction |
| `praxo_stream` | Stream-kind constants and part record |

Implement the deferred interfaces in `praxo_interfaces`; see
`tests/doubles.f90` for native model, tool, and policy examples. Tool arguments
and results use JSON text. Model-provided tool arguments are parsed as JSON
objects and normalized before invocation. `praxo_json` exposes parsed documents
for consumers that need structured access.

```fortran
options%provider => provider
options%tools => tools
options%events => sink
call run_agent(options, state, 'hello', 'caller-generated-run-id', result, error)
if (error%failed()) print *, error%code
```

Callback targets must remain alive for the run. `multi_sink%add` and
`filter_sink%target` retain pointers, so their targets must outlive the sink.
The registry owns a polymorphic copy of each registered tool; pointer components
inside a user-defined tool retain the caller's lifetime obligations. Each run
has local history and does not mutate the input session or options. Sharing a
mutable model, registry, store, or sink across threads requires caller-managed
synchronization.

The caller supplies a unique run ID, which is preserved in results and events.
Zero or negative step limits select eight steps. A nonpositive token limit
disables the usage budget. Model and tool failures propagate; denied policy
actions fail before the corresponding invocation. Context compaction is checked
before each model invocation. Negative usage and counter overflow fail closed.

Optional `limits` and `selection` pointers enable per-run call limits and tool
advertising/invocation checks. Set `redact_pii` (or the legacy `redact_emails`)
to redact model-bound message content, decoded historical tool arguments, and
tool results. Built-in rules cover email, SSN, credit-card, and phone patterns.
Use `fallback_model` and `structured_model`
as native model decorators. Structured repair callbacks receive the previous
output, validation errors, and attempt number.

## Scope and Limits

JSON documents are limited to 262144 input bytes, 4096 value nodes, and 64 nested
containers. Strings preserve trailing spaces and embedded null bytes. Invalid
UTF-8, lone surrogates, malformed numbers, and trailing data are rejected.
Duplicate object keys are retained; lookup and equality use the last value.
Decimal equality avoids binary floating-point rounding for exponents that fit
in signed 64-bit arithmetic; larger exponent spellings compare lexically.
Numeric schema bounds use finite `real64` values. JSON utilities report local
`JSON_INVALID` and `JSON_CAPACITY` statuses; these are not new wire error codes.

Checkpoint allowlists wrap JSON data only; they do not instantiate arbitrary
native types. Envelope size is checked so successfully marshaled values can be
read under the same parser limits.

Schema patterns support ASCII literals, dot, character classes/ranges, anchors,
and `*`, `+`, `?`, plus basic escaped classes. This is not full RE2: groups,
alternation, counted repetitions, Unicode pattern matching, and unsupported
escapes fail explicitly with the local `SCHEMA_PATTERN_UNSUPPORTED` status.
Pattern work is bounded, and unsupported patterns cannot silently accept data.

Path policy is lexical normalization, not OS confinement. It does not resolve
symlinks, reparse points, filesystem case rules, or races. Do not use it as a
substitute for sandbox or filesystem-enforced authorization. UNC and
drive-relative paths are rejected. Plugin parsing validates declarations; it
does not execute plugins or verify signatures. Stream support currently provides
the part record and six contract kind strings, not an asynchronous agent stream.

Memory search currently implements ASCII case folding and lexical ordering of
canonical UTC timestamps. Context estimates normalize valid JSON argument text
before estimating its byte length. Multimodal message blocks and optional Go
hooks not listed in the parity inventory are not implemented.

## Remaining Gates

`api/0.2.0.txt` inventories exported declarations, type layouts, bound
method signatures, and callback interfaces. `api-snapshot.py --check` runs as
part of the test driver; intentional changes require review and regeneration
with `--update`. It is a source declaration check, not a binary ABI guarantee.

The `fortran-conformance` CI job runs native tests, all eleven groups, tooling
tests, and the snapshot check. Passing fixtures covers the declared Core scope;
the parity inventory records the two partial surfaces (asynchronous stream
support and the bounded JSON Schema subset).

The SDK sources are original MIT-licensed code under the repository license.
GNU Fortran and its runtime are separately licensed toolchain dependencies; no
compiler or runtime binaries are vendored here.
