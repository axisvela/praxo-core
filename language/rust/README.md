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
included. A streaming SSE parser is
included; an HTTP OpenAI-compatible client, VFS, and plugin hosts are not yet
implemented.

Source version `0.8.0` is prepared in the repository. The latest source tag and
crates.io package are `rust/v0.6.0` and `praxo-core@0.6.0`. Supported contract:
`SPEC_VERSION` `0.2.0` (`praxo_core::SPEC_VERSION`).

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/rust/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/rust/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/rust/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [crates.io](https://crates.io/crates/praxo-core/0.6.0)

## Install

```bash
cargo add praxo-core@0.6.0
```

## Runnable Examples

- [`examples/provider-fallback`](examples/provider-fallback): fallback model after
  a primary failure, with a deterministic check.
- [`examples/event-sink`](examples/event-sink): lifecycle and tool events through
  `MultiSink` and `FilterSink`, with a deterministic check.
- [`examples/streaming`](examples/streaming): delta callbacks that reconstruct
  the final output, with a deterministic check.
- [`examples/mcp`](examples/mcp): in-process MCP transport for deterministic
  tool discovery and tool calls.
- [`examples/structured-output`](examples/structured-output): JSON Schema
  validation with a deterministic valid/invalid output check.
- [`examples/checkpoint`](examples/checkpoint): application-owned checkpoint
  storage with allowlisted payload encoding.

## Requirements

- Rust 1.80 or newer
- Python 3.10 or newer for the API gate (not a runtime dependency)

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
| `openaicompat` | OpenAI-compatible SSE stream parser |
| `anthropic` | Anthropic Messages mapping with caller-supplied transport |
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

## License

MIT. See [LICENSE](LICENSE).
