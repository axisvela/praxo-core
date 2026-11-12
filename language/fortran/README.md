# Fortran Core

A native Fortran 2008 agent implementation with source tag `fortran/v0.8.0`.
Version `0.6.0` adds cancellation, stream callbacks, a native SSE parser, and
caller-provided batch tool dispatch. Version `0.4.0` replaced the
bounded ASCII matcher with upstream RE2 through a small C ABI library. The
agent loop, JSON, policy, middleware, and human-in-the-loop interrupt decisions
remain Fortran, not a bridge to another agent runtime. All 63 normative vectors
across eleven groups and native regressions pass locally. Source tags do not imply package-registry publication.

## Harmovela Event Sink

```fortran
use praxo_harmovela, only: harmovela_sink
type(harmovela_sink) :: sink
type(event) :: item

sink%base_url = 'http://127.0.0.1:8790/aep/api'
sink%source = 'praxo-core'
sink%spec_version = '0.2'
sink%transport => my_transport
sink%clock => my_clock
item = event('tool.call', 's1', 'run-1', 'echo', '{"text":"hi"}')
call sink%emit(item)
if (sink%failed()) print *, sink%error_message
```

`emit` posts to `{baseURL}/events` through the injected
`harmovela_transport` with `application/json` and the documented
`spec_version`, `id`, `type`, `source`, `created_at`, and merged `payload`
envelope. Event `tool_name` and `arguments` are published as `name` and
`arguments`, alongside `session_id` and `run_id` when present. Inject
`harmovela_clock` for deterministic epochs. A 2xx status clears the sink error;
any other status sets `error_code` to `HARMOVELA_HTTP` and `error_message` to a
bounded message containing the status and response body.

The sink adds no authentication, retries, buffering, ordering, or
exactly-once-delivery guarantee. Apply caller-side filtering because event data
may contain sensitive content, and use HTTPS for remote endpoints.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/fortran/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/fortran/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/fortran/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: Source / CMake

## Build and Test

Use GNU Fortran, a C++17 compiler, CMake 3.22+, Ninja, Git, and Python 3.10+:

```sh
python language/fortran/run-tests.py
```

See [SETUP.md](SETUP.md) for the recorded environment, configuration, test
commands, and local results.

Set `FC` or pass `--compiler /path/to/gfortran` if needed. The driver compiles
with Fortran 2008 mode, warnings as errors, and runtime checks. Generated
modules and executables are confined to `language/fortran/build/`.

Set `CXX` or pass `--cxx /path/to/g++` to select the C++ compiler. The driver
prefers a `g++` next to the Fortran compiler when available, avoiding mixed
toolchain runtimes. The first build downloads pinned RE2 and Abseil revisions
from their official repositories; subsequent builds reuse those source trees.
For offline builds, prepopulate the sources or configure CMake's
`FETCHCONTENT_SOURCE_DIR_ABSEIL` / `FETCHCONTENT_SOURCE_DIR_RE2` overrides with
the reviewed revisions. Downloads and build failures are fatal; there is no
silent fallback to the old matcher or to Python/Go regex.

The driver builds/tests/installs `praxo_re2` under `build/re2-install` and links
the Fortran suites against that installed library. Consumers must link
`-L<prefix>/lib -lpraxo_re2` and provide the shared library and compatible C++
runtime at execution time. Windows requires `<prefix>/bin` on the DLL search
path; Unix consumers need a loader path or rpath for `<prefix>/lib`.
Redistributed bridge binaries must include the installed upstream licenses;
see [native dependencies](native/DEPENDENCIES.md). These new native deployment
requirements are the reason for the pre-1.0 minor change to `0.4.0`; `0.6.0`
is an additive agent-lifecycle release.

Python is only a build/test dependency. `conformance.py` translates the declared
JSON fixtures into Fortran test inputs and assertions; every behavior under test
runs in the compiled Fortran Core implementation. The generator verifies the complete vector
group inventory and rejects unknown operations rather than silently skipping
them. Python is not required by a compiled Core consumer.

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
| `praxo_schema`, `praxo_pattern` | `schema`, `schema_from_json`, contract validation, and upstream RE2 UTF-8 pattern matching |
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

## OpenAI-Compatible Adapter

`praxo_openai` provides a non-streaming `openai_compatible` type that extends
`model`. It maps role/content messages, assistant tool calls, tool results, and
tool declarations to the OpenAI request shape, and maps `message.content`,
`message.tool_calls` (arguments validated as a JSON object), and `usage` back to
`response`. The Fortran `response` type has no finish-reason field, so
`finish_reason` is read but not surfaced. Invalid tool arguments set
`PROVIDER_JSON`; a missing base URL or transport sets `PROVIDER_HTTP` before any
transport call.

No HTTP client is bundled. `openai_transport` is an abstract interface; callers
must supply a procedure that posts the payload and returns the response body.
Adding a transport is a separate dependency decision: a reviewed libcurl C ABI
binding (MIT-style license) or an `execute_command_line` wrapper around an
external client (process-dependent, not a library dependency) would each need
its own build, licensing, and error-mapping review. Tests inject a fake
transport and make no network calls. Streaming is not implemented.

```fortran
use praxo_openai
type(openai_compatible) :: adapter
adapter%base_url = 'https://api.example/v1'
adapter%model_name = 'provider-model'
adapter%transport => my_transport
options%provider => adapter
```

`my_transport(url, payload, api_key, error)` returns the response body as an
allocatable character string and sets `error%code` on failure.

## Anthropic and Gemini Adapters

`praxo_anthropic` and `praxo_gemini` provide transport-seam
`anthropic_compatible` and `gemini_compatible` types for the Messages and
generateContent APIs.

```fortran
use praxo_anthropic
type(anthropic_compatible) :: claude
claude%base_url = 'https://api.anthropic.com'
claude%model_name = 'claude-sonnet-4-5'
claude%api_key = 'ak'
claude%transport => anthropic_http
```

Both adapters map tool calls, tool schemas, usage, and provider errors. Callers
supply the HTTP transport.

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

Schema patterns use RE2's full default syntax and builtin Unicode
tables: groups, alternation, counted repetition, inline flags, Unicode literals,
and properties such as `\p{Han}`, `\p{Greek}`, and `\p{L}`. Matching is unanchored
search unless the pattern supplies anchors, as in Go's schema validator.
UTF-8 code points, not bytes, are matched by dot; NUL bytes and trailing spaces
are preserved. Patterns are limited to 4096 bytes, subjects to 262144 bytes,
and RE2's `max_mem` budget to 8 MiB (not an OS process-memory cap). Unicode normalization and locale-specific
matching are not provided. PCRE lookaround and backreferences are not RE2
features and remain errors. C++ RE2 and Go regexp can differ in syntax and
Unicode table versions; this is not a claim of universal Go equivalence.

Invalid regex syntax reports local `SCHEMA_PATTERN_UNSUPPORTED`, invalid UTF-8
reports `JSON_INVALID`, resource limits report `JSON_CAPACITY`, and unexpected
bridge errors report `SCHEMA_INVALID`. None of these failures is a successful
non-match; callers must inspect `error%failed()`.

Since `0.2.2`, malformed supported schema fields are rejected with the local
`SCHEMA_INVALID` status. Default-constructed schemas and failed parse results
also fail with that status instead of reading unallocated storage. Check both
`error%failed()` and the validation errors: an empty errors array is not a pass
when the operation failed. An explicit `{}` or `null` schema is unrestricted,
matching the Go parser; an empty enum and zero numeric bounds are treated as
unset. Invalid JSON still reports `JSON_INVALID`/`JSON_CAPACITY`. These statuses
are local to the Fortran API, not additions to the shared wire error contract.

Path policy is lexical normalization, not OS confinement. It does not resolve
symlinks, reparse points, filesystem case rules, or races. Do not use it as a
substitute for sandbox or filesystem-enforced authorization. UNC and
drive-relative paths are rejected. Plugin parsing validates declarations; it
does not execute plugins or verify signatures. Stream support provides the typed
part record (run/session IDs, kind, step, data, timestamp) and six contract kind
strings, not an asynchronous agent stream.

Memory search currently implements ASCII case folding and lexical ordering of
canonical UTC timestamps. Context estimates normalize valid JSON argument text
before estimating its byte length. Multimodal message blocks and optional Go
hooks not listed in the parity inventory are not implemented.

## Remaining Gates

`api/0.6.0.txt` inventories exported declarations, type layouts, bound
method signatures, and callback interfaces. `api-snapshot.py --check` runs as
part of the test driver; intentional changes require review and regeneration
with `--update`. It is a source declaration check, not a binary ABI guarantee.
Historical snapshots through `0.4.0` are retained. `0.6.0` adds the
cancellation, stream, SSE, and parallel-dispatch declarations.

The `fortran-conformance` CI job runs native tests, all eleven groups, tooling
tests, and the snapshot check. Passing fixtures covers the declared Core scope.
The RE2/Unicode suite also runs against the installed bridge. The parity
inventory still records JSON Schema as partial because JSON/numeric limits
and schema coverage are separate from regex support; asynchronous agent
streaming remains outside the declared Core surface.

See [CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.

The Core sources are original MIT-licensed code under the repository license.
GNU Fortran and its runtime are separately licensed toolchain dependencies; no
compiler or runtime binaries are vendored here.
RE2 (BSD-3-Clause) and Abseil (Apache-2.0) retain their licenses even though the
Fortran Core and original ABI bridge are MIT.
