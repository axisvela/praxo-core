# PRAXO-CORE Rust Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This crate is its
native Rust Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, and plugin manifest parsing. It runs in-process and does not
require a hosted service.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

**Status:** core. The package passes all eleven conformance vector groups.
Context budgets, middleware, streaming callbacks, cancellation, bounded parallel
tools, human-in-the-loop interrupt decisions, and the synchronous agent loop are
included. A streaming SSE parser is always available. An HTTP
OpenAI-compatible client is available behind the optional `http-ureq` feature;
VFS and plugin hosts are not yet implemented.

The latest source tag is `rust/v0.11.1`; the published crates.io package is
`praxo-core@0.11.1`. Supported contract:
`SPEC_VERSION` `0.2.0` (`praxo_core::SPEC_VERSION`).

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/rust/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/rust/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/rust/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [crates.io](https://crates.io/crates/praxo-core/0.11.1)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Get started

Install the published package:

```bash
cargo add praxo-core@0.11.1
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [Rust documentation](https://axisvela.github.io/praxo-core/languages/rust/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/rust/examples`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/mcp) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/identity-policy) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/service) |
| Approve or edit a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/hitl) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/session-checkpoint) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/event-sink) |

## Install

```bash
cargo add praxo-core@0.11.1
```

## Requirements

- Rust 1.80 or newer
- Python 3.10 or newer for the API gate (not a runtime dependency)
- `http-ureq` is optional and adds the HTTP OpenAI-compatible client; the default
  build remains dependency-light

## Build and test

```bash
cd language/rust
cargo test
cargo run --quiet --bin conformance
python api-snapshot.py --check
python -m unittest discover -s tests -p "test_*.py" -v
```

## Usage

```rust
use std::sync::Arc;
use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::model::{Message, Model, Request, Response};

struct EchoModel;

impl Model for EchoModel {
    fn generate(&self, _request: &Request) -> praxo_core::errors::Result<Response> {
        Ok(Response {
            message: Message::assistant("hello", Vec::new()),
            ..Response::default()
        })
    }
}

let agent = Agent::new(AgentOptions::new(Arc::new(EchoModel)))?;
let result = agent.run(&Session::new("session-1"), "hi")?;
println!("{} {}", result.output, result.steps);
```

## OpenAI-compatible HTTP client

Enable the optional feature and use `OpenAICompatible::with_ureq` in the
published crate:

```toml
praxo-core = { version = "0.11.1", features = ["http-ureq"] }
```

```rust
use std::sync::Arc;
use praxo_core::openai_compat::{OpenAICompatConfig, OpenAICompatible};

let model = OpenAICompatible::with_ureq(OpenAICompatConfig {
    base_url: "http://localhost:11434/v1".to_string(),
    api_key: String::new(),
    model: "qwen3.5:4b".to_string(),
    timeout_secs: 120,
});
let agent = Agent::new(AgentOptions::new(Arc::new(model)))?;
```

The adapter maps `tool_calls`, `tool_call_id`, tool parameters, usage, and
streaming content. Hosted HTTPS endpoints use the `native-tls` path enabled by
`http-ureq`.

## Contract Surface

| Module | Contract |
| --- | --- |
| `model` | Model, messages, tool specs, request/response, usage |
| `tool` | Tool, Registry, FuncTool, Gateway, GatewayTool, gateway_tools |
| `event` | Event, Sink, multi/filter sinks |
| `policy` | Hook, Decision, PathChecker |
| `memory` | Store, MemoryRecord, MemoryStore |
| `checkpoint` | Allowlist |
| `context` | budgets, summarization, offload, AGENTS.md |
| `middleware` | call limits, fallback, PII, structured output, tool selection |
| `agent` | Agent, AgentOptions, Session, RunResult |
| `toolcall` | tool-call parsing and markup stripping |
| `jsonschema` | `Schema`, `from_json`, `validate` over the documented subset |
| `plugin` | Manifest v1 parsing and validation |
| `openaicompat` | SSE stream parser; `OpenAICompatible` HTTP client behind `http-ureq` |
| `anthropic` | Anthropic Messages mapping with caller-supplied transport; `StreamingModel` via `send_stream` |
| `gemini` | Gemini generateContent mapping with caller-supplied transport |
| `harmovela` | Harmovela HTTP event sink and injectable transport |
| `mcp` | Native stdio MCP client, tool adapters, and registry helper |

Wire codecs preserve the Go names, including `image_url`, `runId`, and
`plugin_id`.

## Harmovela event sink

`harmovela::Sink` posts lifecycle events to `{base_url}/events` as JSON
envelopes with `spec_version`, `id`, `type`, `source`, `created_at`, and a
payload that merges the event data with `session_id` and `run_id` when present.

```rust
use std::sync::Arc;
use praxo_core::harmovela::Sink;

let events = Arc::new(Sink::new("http://127.0.0.1:8790/aep/api"));
let mut options = AgentOptions::new(model);
options.events = Some(events);
```

Use `Sink::with_transport` to inject a fake transport in tests. The default
transport speaks plain HTTP; inject a `Transport` for HTTPS. Limits: the sink
adds no authentication, retries, buffering, acknowledgements, ordering, or
exactly-once delivery. Filter sensitive event data at the caller, and use HTTPS
for remote endpoints.

## MCP stdio client

`mcp::McpClient` starts a child process that speaks newline-delimited JSON-RPC
2.0 over stdio. It performs the `initialize` / `notifications/initialized`
handshake, follows `tools/list` cursors, rejects repeated cursors and duplicate
names, preserves `inputSchema`, and maps `tools/call` structured or text content.

```rust
use praxo_core::mcp::{McpClient, McpServerConfig};
use praxo_core::tool::Registry;

let client = McpClient::connect(
    McpServerConfig::new("my-mcp-server").arg("--stdio"),
).expect("connect");
let mut registry = Registry::new();
client.register_tools(&mut registry).expect("register tools");
```

`register_tools` uses the normal `Registry` and `Tool` seam, so policy and tool
authorization still apply. `McpToolAdapter::spec` and `McpTool::spec` preserve
the model-facing input schema. Failures use `MCP_PROTOCOL`, `MCP_TRANSPORT`,
`MCP_HANDSHAKE`, `MCP_PAGINATION`, `MCP_DUPLICATE_TOOL`, `MCP_TOOL_ERROR`,
`MCP_RPC`, `MCP_TIMEOUT`, `MCP_CLOSED`, and `MCP_CANCELLED` codes.

Limits: stdio transport only; no remote transport, authentication, sandbox
isolation, or schema promotion. Tool output is untrusted and MCP authentication
belongs to the child process. `McpClient::close` and `Drop` terminate the child;
in-flight timeouts send `notifications/cancelled` but do not prove remote work
stopped. The included tests use a deterministic fake server, not a live service.

## Process plugin host

`plugin_process::ProcessHost` speaks the framework JSON-Lines process plugin
protocol: token authentication through `PRAXOVELA_PLUGIN_TOKEN`, health
handshake, invocation timeout, cooperative cancel, and typed call errors.
## Conformance

The runner reads `../../spec/vectors/*.json`. A released Core implementation must pass every vector
and keep `spec/parity.md` current.

## API Gate

`api-snapshot.py` uses stable compiler-generated rustdoc, not a source regex
scanner. It records reachable public declarations, fields, inherent methods,
and direct trait implementations, and checks implemented symbols against
[`spec/parity/rust.md`](../../spec/parity/rust.md). Stale, unlinked rustdoc pages
are excluded. Auto traits, blanket implementations, and expanded alias internals
are excluded to avoid compiler/platform-specific noise.

The baseline is [`api/0.3.0.txt`](api/0.3.0.txt). Regenerate it with
`python api-snapshot.py` only after reviewing an intentional API change.
This is not a binary ABI or automated semver-compatibility guarantee. Serde/wire
attributes still require specification review and conformance tests; they are
not inferred from rustdoc. The gate uses `Cargo.lock` and adds no Rust dependencies.

## Release Notes

See [CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility
notes.


## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for Rust.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [biodiversity-alerts](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/biodiversity-alerts) | Classify fixed labeled observations and draft a ranger review. No production write or external system access. |
| [bug-repair](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/bug-repair) | Reproduces a fixed bug, drafts a patch and reruns a fixture test. No PR creation or repository write. |
| [code-review](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/code-review) | Reviews a fixed diff and dependency manifest, cites findings and uncertainty and drafts comments. No comments are posted. |
| [cold-chain](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/cold-chain) | A bounded first slice of TL-04, not a refrigeration-control or clinical-cargo system. It computes fixed temperature excursions and drafts a review-only transfer review. No refri... |
| [construction-safety](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/construction-safety) | A bounded first slice of BE-01, not a certified safety inspection. It reads fixed inspection labels for one site, drafts a review-only remediation checklist and records zero cer... |
| [copyright-evidence](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/copyright-evidence) | Compare fixed authorized assets and draft an evidence packet. No production write or external system access. |
| [dlp-redaction](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/dlp-redaction) | Inspect a fixed export and draft a review-only redaction. No production write or external system access. |
| [drone-fleet-plan](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/drone-fleet-plan) | Simulate fixed waypoints and conflict checks, then draft a plan. No production write or external system access. |
| [fleet-map](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/fleet-map) | Replay fixed road-topology changes and draft a reviewed map patch. No production write or external system access. |
| [household-robot](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/household-robot) | A bounded first slice of PE-04, not a robot controller. It observes fixed robot state with freshness, drafts a bounded review-only action that requires cancel confirmation, and... |
| [iot-gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway) | A scoped edge tutorial over the published MIT `praxo-core` Rust crate. It reads one fixed gateway snapshot through an application-owned `GatewayAdapter` trait, asks a determinis... |
| [lab-loop](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/lab-loop) | A bounded first slice of SC-03, not an autonomous laboratory. It replays a fixed parameter/result loop with deterministic limits and drafts review-only next parameters. No labor... |
| [leak-localization](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/leak-localization) | A bounded first slice of CT-02, not a leak-detection or dispatch system. It ranks fixed synthetic pressure anomalies and drafts a review-only inspection list. No valve isolation... |
| [livestock-monitor](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/livestock-monitor) | A bounded first slice of AE-01, not a veterinary or feeding-control system. It summarizes fixed animal observations and drafts a review-only veterinary request. No diagnosis, is... |
| [mining-slope](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/mining-slope) | A bounded first slice of BE-03, not a collapse-prediction or dispatch system. It reads fixed slope displacement indicators and drafts a review-only alert. No collapse prediction... |
| [pentest-lab-review](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/pentest-lab-review) | Inventory one allowlisted loopback lab and draft a review-only report. No production write or external system access. |
| [privacy-agent](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/privacy-agent) | Classify fixed messages and draft a review-only deletion request. No production write or external system access. |
| [quant-risk](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/quant-risk) | Replays fixed prices, enforces a deterministic exposure limit and drafts a review-only order. No trade or latency claim. |
| [supply-chain-review](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/supply-chain-review) | Compare fixed manifests and draft a reviewed version pin. No production write or external system access. |
| [threat-hunting](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/threat-hunting) | Search fixed logs and draft a cited synthetic TTP timeline. No production write or external system access. |

Index: [language/rust/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for this language yet. Candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).

Planning context: [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/), [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), and [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/). Chinese: [教程计划](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/), [候选场景](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/), [教程目录](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/).

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


## License

MIT. See [LICENSE](LICENSE).
