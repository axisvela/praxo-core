# PRAXO-CORE OCaml __VERSION__

PRAXO-CORE is an embeddable, MIT-licensed AI agent framework. This standalone
source package is its native OCaml Core, published as `praxo-core`.

It includes the native agent loop, tools and tool-call parsing, memory,
checkpoint allowlists, lexical path policy, context compaction, event sinks,
middleware helpers, tool selection, schema and manifest validation, streaming
OpenAI-compatible, Anthropic, and Gemini adapters, MCP/OpenTelemetry seams,
retrieval, synchronous delegation, and an optional process plugin host. It does
not call Go or another language Core and has no cross-language process bridge.

Standalone Dune/opam source package generated from the canonical repository;
staging alone does not establish opam availability. See `PROVENANCE.json` for
the canonical tag reference, HEAD identity and hashes of the actual worktree
inputs. Worktree files can differ from HEAD and the tag; a tag reference does
not certify the packaged bytes.

## Install and Build

Requires OCaml >= 4.14 and Dune >= 3.0. Tests run in bytecode mode. The `unix`
library ships with OCaml and is not a separate opam dependency. Tests are
offline and use a native OCaml process-plugin fixture; no Python runtime is
required.

```sh
dune build -p praxo-core
dune runtest -p praxo-core
opam install . --with-test
```

To install from this source directory without relying on registry publication:

```sh
opam pin add praxo-core . --with-test
```

Use `(libraries praxo-core)` in a consumer's Dune library or executable. The
module is `Praxo_core` (the library is unwrapped). Callers supply provider HTTP
transports; no network client or credentials are bundled.

The packaged tests include both canonical test modules, a native OCaml
process-plugin fixture, and all shared vectors under `tests/spec/vectors`.

## What Is Included

- Agent loop with step and token budgets, call limits, PII redaction,
  structured output, tool selection, policy hooks, HITL interrupts, and events.
- JSON, tool-call parsing, schema validation, and plugin manifest validation.
- OpenAI-compatible, Anthropic, and Gemini request/response adapters, including
  SSE streaming through caller-supplied transports.
- Sessions, memory, checkpoints, lexical path grants, context compaction,
  retries, event sinks, and middleware helpers.
- MCP and OpenTelemetry transport seams, retrieval, synchronous delegation, and
  a JSON-Lines process plugin host.

## API

```ocaml
let node = Praxo_core.parse_json "{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}"
let raw = Praxo_core.encode_json node
let _call = Praxo_core.parse_tool_call raw
let _paths = Praxo_core.validate_schema (Praxo_core.parse_json "{\"type\":\"string\"}") node
let _manifest = Praxo_core.validate_manifest "{}"
```

Public declarations are inventoried in the [API snapshot](__REPOSITORY__/blob/main/language/ocaml/api/__VERSION__.txt).
`validate_manifest` returns `Some manifest` only for a valid declaration.

## Human-in-the-loop Approval

Set `agent_interrupt_on` and either `agent_on_interrupt_decision` or
`agent_on_interrupt`. Decisions use `interrupt_approve`, `interrupt_edit`,
`interrupt_reject`, and `interrupt_respond`; edited arguments are authorized
again before invocation.

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

## Provider Adapters

`openai_model` maps requests to `POST {baseUrl}/chat/completions`.
`anthropic_model` and `gemini_model` target the native Messages and
generateContent APIs. All three support caller-supplied HTTP transports,
assistant tool calls, token usage, provider error codes, and SSE streaming via
`generate_stream` and `agent_on_delta`.

```ocaml
let model = Praxo_core.openai_model {
  Praxo_core.openai_base_url = "https://api.example.com/v1";
  openai_model = "provider-model-id";
  openai_api_key = Some "secret";
  openai_tool_choice = Some "auto";
} transport
```

## Harmovela, OpenTelemetry, Retrieval, and Delegation

`harmovela_sink` posts events to `POST {baseURL}/events` with the documented
envelope. `otel_sink_new` maps events to OTLP/HTTP spans with an allowlist for
event-data attributes. `retrieve_documents` calls a caller-supplied retriever,
and `subagent_run` runs a caller-supplied synchronous child task and returns a
terminal task state. None of these seams bundle authentication, durable queues,
retries, or cross-process workers.

## Process Plugin Host

`start_plugin_process`, `invoke_plugin_process`, and `stop_plugin_process`
speak the framework JSON-Lines process plugin protocol with token
authentication, a health handshake, invocation timeouts, stderr draining, and
typed errors. The host owns the child process pipes; it is not an OS sandbox.

## Tutorials and Examples

Runnable OCaml examples cover the consumer loop, live-model seam, structured
output, MCP, streaming, checkpoints, fallback, HITL, and service authentication.

Scenario tutorials:

- [architecture-graph](__REPOSITORY__/tree/main/language/ocaml/Tutorial/architecture-graph): bounded application/API graph review.
- [bom-review](__REPOSITORY__/tree/main/language/ocaml/Tutorial/bom-review): fixed drawing conflict and review-only BOM.
- [code-review](__REPOSITORY__/tree/main/language/ocaml/Tutorial/code-review): fixed diff and dependency review.
- [contract-review](__REPOSITORY__/tree/main/language/ocaml/Tutorial/contract-review): fixed clause redlines.
- [static-diagnostics](__REPOSITORY__/tree/main/language/ocaml/Tutorial/static-diagnostics): structured diagnostics review.

- [Examples](__REPOSITORY__/tree/main/language/ocaml/examples)
- [Tutorial index](__REPOSITORY__/tree/main/language/ocaml/Tutorial)
- [Tutorial catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/)

## Current Limits

- The verified target is OCaml 4.14.2 bytecode. Native `ocamlopt`, other
  versions, and macOS are not yet verified.
- JSON input and output are bounded to 1,048,576 characters and nesting to 64.
  Tool-call input is bounded to 262,144 characters.
- JSON strings are UTF-8 and accept surrogate escapes; the encoder escapes
  control characters. Numbers are finite IEEE doubles, so large integers and
  exact decimal spellings may lose precision.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. DSML, invoke, todo, and skill-install formats are not implemented.
  Markup stripping is not an authorization control or security sanitizer.
- Schema patterns accept a bounded anchored ASCII subset, not full RE2.
  JSON Schema behavior follows the documented subset, including zero bounds
  treated as unset and ignored unknown keywords.
- Manifest checks validate declarations only; they do not verify signatures,
  establish trust, execute plugins, or enforce OS sandboxing.
- Path checks are lexical and do not resolve symlinks or reparse points. They
  are not an OS containment boundary.
- Sessions, checkpoints, and events are not durable or exactly-once. Run IDs can
  collide and session history is not persisted automatically.
- Core-local exceptions are not new shared wire error codes. Passing all eleven
  vector groups does not imply full Framework or Go feature parity.

## References

- [Documentation](https://axisvela.github.io/praxo-core/languages/ocaml/)
- [Canonical source](__REPOSITORY__/tree/main/language/ocaml)
- [API interface](__REPOSITORY__/blob/main/language/ocaml/src/praxo_core.mli)
- [API snapshot](__REPOSITORY__/blob/main/language/ocaml/api/__VERSION__.txt)
- [Coding agents](https://axisvela.github.io/praxo-core/getting-started/coding-agents/)
- [Release notes](__REPOSITORY__/blob/main/language/ocaml/CHANGELOG.md)
- [Security](__REPOSITORY__/blob/main/SECURITY.md)

Licensed under MIT; see `LICENSE`. OCaml and its runtime are separate toolchain
components, not vendored code.

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- Documentation: <https://axisvela.github.io/praxo-core/>
