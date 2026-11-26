# PRAXO-CORE for OCaml

PRAXO-CORE is an embeddable, MIT-licensed AI agent framework. This package is its
native OCaml Core with source tag `ocaml/v0.11.0`. It passes all eleven vector
groups on OCaml 4.14.2 bytecode and includes the native agent loop, memory store,
checkpoint allowlist, lexical path policy, context compaction, event sinks,
middleware helpers, tool selection, streaming OpenAI-compatible, Anthropic, and
Gemini model adapters, and an optional process plugin host. It does not call Go
or another language Core and has no cross-language process bridge.

The experimental path check is lexical and does not resolve symlinks or reparse
points; it must not be used as an OS containment boundary. The loop does not
persist session history and its run IDs can collide. Callback exceptions trigger
a best-effort `run.failed` notification before the original exception is
re-raised; notification failure does not replace it. Do not treat the loop as
production-ready.

Local validation uses OCaml 4.14.2 in bytecode mode, and the Linux CI job runs
the same full suite. The split repository is `axisvela/praxo-core-ocaml` and is
aligned to this release. No opam package is published yet: previous submissions
were closed, and the replacement registry submission is pending review. See
[publication status](PUBLISHING.md) and the
[official opam packaging guide](https://opam.ocaml.org/doc/Packaging.html#Using-opam-publish-with-a-project-hosted-on-Github). Native
`ocamlopt` compilation, commercial support, production readiness, and a delivery
date are not claimed.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [opam (pending)](https://github.com/axisvela/praxo-core-ocaml)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Install

Use the source checkout at `language/ocaml` and the build instructions below.
`opam install praxo-core` is not available while registry submission is pending.

## Representative Flows

- [Representative chain](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/examples/representative-chain): deterministic MCP
  record, final-argument authorization, child delegation, OTel/Harmovela events,
  and an edited denial with zero effects.
- [Advanced delegation](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/examples/advanced-delegation): application-level
  parent/child scope plus six governance negative checks.

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

For the standalone Dune/opam package layout and installed-library consumer,
see [source package validation](PUBLISHING.md#source-package-validation).
Staging a package does not publish it to opam.

The Core is split by responsibility under `src/`: `praxo_types`, JSON and
tool-call parsing, schema and manifest validation, provider adapters, the
process plugin host, runtime helpers, middleware, the agent loop, and MCP/OTel
seams. `src/praxo_core.ml` re-exports those modules as the public
`Praxo_core` API. Use `run-tests.py` for the dependency-ordered bytecode build:

```bash
python language/ocaml/run-tests.py
```

Examples and tutorials load `src/praxo_core_bundle.ml`, which registers the
internal modules with `#mod_use` before opening the public module.

## API

```ocaml
let node = Praxo_core.parse_json "{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}"
let raw = Praxo_core.encode_json node
let _call = Praxo_core.parse_tool_call raw
let _paths = Praxo_core.validate_schema (Praxo_core.parse_json "{\"type\":\"string\"}") node
let _manifest = Praxo_core.validate_manifest "{}"
```

Public declarations are inventoried in [`api/0.11.0.txt`](api/0.11.0.txt).
`validate_manifest` returns `Some manifest` only for a valid declaration.

## Human-in-the-loop Approval

Set `agent_interrupt_on` and either `agent_on_interrupt_decision` or
`agent_on_interrupt`. Decisions use `interrupt_approve`, `interrupt_edit`,
`interrupt_reject`, and `interrupt_respond`; edited arguments are authorized
again before `tool.call`. `agent_action_policy` receives the action kind,
session, tool name, and arguments so reauthorization can reject edited values.

```ocaml
let options = {
  (Praxo_core.agent_options model) with
  Praxo_core.agent_tools = [write_note];
  agent_allowed_tools = ["write_note"];
  agent_action_policy = Some authorize;
  agent_interrupt_on = ["write_note"];
  agent_on_interrupt_decision = Some (fun _ ->
    Praxo_core.interrupt_decision_make Praxo_core.interrupt_approve);
}
```

See the [OCaml HITL example](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/examples/hitl) for approve and edited-denial scenarios.

## OpenAI-Compatible Adapter

`openai_model` maps Core requests to `POST {baseUrl}/chat/completions`,
including messages, tools, tool choice, assistant tool calls, token usage, and
provider HTTP errors (`PROVIDER_HTTP`). `generate_stream` sets `stream: true`, parses SSE, reassembles content,
fragmented tool calls, and usage, and calls the delta callback. Set `agent_on_delta` to use it through the agent.

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

## Anthropic and Gemini Adapters

`anthropic_model` and `gemini_model` map Core requests to the native Messages
and generateContent APIs over the same injected `transport` seam, including
system messages, text content blocks, tools, tool choice, tool calls, usage,
`PROVIDER_HTTP` errors, and SSE streaming through `generate_stream`.

```ocaml
let claude = Praxo_core.anthropic_model {
  Praxo_core.anthropic_base_url = "https://api.anthropic.com";
  anthropic_model = "claude-sonnet-4-5";
  anthropic_api_key = "ak";
  anthropic_version = "2023-06-01";
  anthropic_max_tokens = 1024;
  anthropic_tool_choice = Some "auto";
} transport
```

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

## OpenTelemetry, Retriever, and Delegation Seams

`otel_sink_new` maps Core events to OTLP/HTTP spans over a caller-supplied
`otel_transport`; event data is excluded unless its key is allowlisted with
`otel_allowed_data_keys`. `otel_emit` raises `OTEL_HTTP` for non-2xx responses.

```ocaml
let sink = Praxo_core.otel_sink_new
  "https://otel.example/v1/traces"
  (fun method_name url content_type body -> (200, ""))
  (fun () -> 1794294000000000000)

Praxo_core.otel_emit sink event
```

`retrieve_documents` calls a `retriever` function with a query and limit and
returns `document` values. `subagent_run` runs a caller-supplied
`subagent_runner` synchronously and returns a `subagent_task` in a terminal
state. It does not provide an asynchronous manager, durable queue, or
cross-process worker.

## Process plugin host

`start_plugin_process` / `invoke_plugin_process` / `stop_plugin_process` speak
the framework JSON-Lines process plugin protocol with token authentication,
health handshake, invocation timeout, and typed errors.

## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for OCaml.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [architecture-graph](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/architecture-graph) | A bounded first slice of OG-01, not an enterprise-architecture control plane. It compares a fixed application/API graph with stated standards and drafts review-only change findings. |
| [bom-review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/bom-review) | A bounded first slice of [IN-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not CAD/BIM parsing or engineering certification. It reads a fixed parsed drawing, reports one clearance conflict, and drafts a review-only BOM. No CAD access or live model. |
| [code-review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/code-review) | A bounded first slice of [SE-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a full security or license audit. It reads a fixed diff and dependency manifest, flags a high-severity unsafe-shell rule and a missing test, and drafts a review-only comment set. |
| [contract-review](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/contract-review) | A bounded first slice of [FC-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not legal advice or an e-signature system. It compares fixed contract clauses to a redline set and drafts review-only redlines. No document store or live model. |
| [static-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial/static-diagnostics) | A bounded static-analysis review tutorial. It parses structured diagnostic lines, counts high/low rules, returns source locations, and chooses a review level from the actual counts. No compiler integration or source edit. |

Index: [language/ocaml/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for this language yet. Candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).

Planning context: [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/), [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), and [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/). Chinese: [教程计划](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/), [候选场景](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/), [教程目录](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/).

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

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>

