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

Package version: `0.3.0`. The crates.io package `praxo-core@0.3.0` is published
from source tag `rust/v0.3.0`. Supported contract: `SPEC_VERSION` `0.2.0`
(`praxo_core::SPEC_VERSION`).

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/rust/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/rust/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/rust/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [crates.io](https://crates.io/crates/praxo-core/0.3.0)

## Install

```bash
cargo add praxo-core@0.3.0
```

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
| `harmovela` | Harmovela HTTP event sink and injectable transport |

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
