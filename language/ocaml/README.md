# PRAXO-CORE for OCaml

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native OCaml Core with source tag `ocaml/v0.3.0`. It passes all eleven vector
groups on OCaml 4.14.2 bytecode and includes the native agent loop, memory store,
checkpoint allowlist, lexical path policy, context compaction, event sinks,
middleware helpers, tool selection, and a non-streaming OpenAI-compatible model
adapter. It does not call Go or another language Core; there is no process
bridge or plugin host.

The experimental path check is lexical and does not resolve symlinks or reparse
points; it must not be used as an OS containment boundary. The loop does not
persist session history and its run IDs can collide. Callback exceptions trigger
a best-effort `run.failed` notification before the original exception is
re-raised; notification failure does not replace it. Do not treat the loop as
production-ready.

Local validation uses OCaml 4.14.2 in bytecode mode, and the Linux CI job runs
the same full suite. The split repository `axisvela/praxo-core-ocaml` prepares
opam package `praxo-core` 0.3.0; opam-repository PR #31106 is pending. Native
`ocamlopt` compilation, commercial support, production readiness, and a delivery
date are not claimed.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [opam (pending)](https://github.com/axisvela/praxo-core-ocaml)

## Install

```bash
opam install praxo-core
```

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
ocamlc -c praxo_core.mli
ocamlc -c praxo_core.ml
ocamlc -c praxo_tests.ml
ocamlc -o build/praxo_tests praxo_core.cmo praxo_tests.cmo
ocamlrun build/praxo_tests ../../spec
```

## API

```ocaml
let node = Praxo_core.parse_json "{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}"
let raw = Praxo_core.encode_json node
let _call = Praxo_core.parse_tool_call raw
let _paths = Praxo_core.validate_schema (Praxo_core.parse_json "{\"type\":\"string\"}") node
let _manifest = Praxo_core.validate_manifest "{}"
```

Public declarations are inventoried in [`api/0.3.0.txt`](api/0.3.0.txt).
`validate_manifest` returns `Some manifest` only for a valid declaration.

## OpenAI-Compatible Adapter

`openai_model` maps Core requests to `POST {baseUrl}/chat/completions`,
including messages, tools, tool choice, assistant tool calls, token usage, and
provider HTTP errors (`PROVIDER_HTTP`). Streaming is not implemented.

```ocaml
let config = {
  Praxo_core.openai_base_url = "https://api.example.com/v1";
  openai_model = "provider-model-id";
  openai_api_key = Some "secret";
  openai_tool_choice = Some "auto";
}

let transport request = (* perform request.http_method/http_url/http_headers/http_payload *)
  { Praxo_core.http_status = 200; http_body = "..." }

let model = Praxo_core.openai_model config transport
```

The adapter does not bundle an HTTP client, so the package keeps its
dependency-free build. Supply a `transport` for production or tests; native
tests use a fake transport.

## Harmovela Event Sink

`harmovela_sink` posts Core events to `POST {baseURL}/events` with the documented
envelope (`spec_version`, `id`, `type`, `source`, `created_at`, `payload`). It
reuses the injectable `transport` type and a UTC nanosecond clock, so the package
keeps its dependency-free build.

```ocaml
let transport request = (* perform request.http_method/http_url/http_headers/http_payload *)
  { Praxo_core.http_status = 201; http_body = "" }

let config = Praxo_core.harmovela_config
  "http://127.0.0.1:8790/aep/api" transport
  (fun () -> 1794294000000000000)

let sink = Praxo_core.harmovela_sink config
```

`harmovela_emit` accepts any 2xx response and raises `Core_error` with
`HARMOVELA_HTTP`, the status, and a bounded body otherwise. The sink has no
authentication, retries, buffering, ordering, or exactly-once guarantee; filter
sensitive event data caller-side and use HTTPS for remote endpoints.

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
