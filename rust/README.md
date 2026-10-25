# PRAXO-CORE Rust SDK

Rust implementation of the PRAXO-CORE contract. The normative contract is
[`spec/`](../spec/README.md); Go remains the reference implementation.

**Status:** core. The package passes all eleven conformance vector groups.
Context budgets, middleware, and the synchronous agent loop are included. The
OpenAI-compatible adapter, VFS, and plugin hosts are not yet implemented.

Package version: `0.1.0`. Supported contract: `SPEC_VERSION` `0.2.0`
(`praxo_core::SPEC_VERSION`).

## Requirements

- Rust 1.80 or newer

## Build and test

```bash
cd rust
cargo test
cargo run --quiet --bin conformance
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
| `tool` | Tool, Registry, FuncTool |
| `event` | Event, Sink, multi/filter sinks |
| `policy` | Hook, Decision, PathChecker |
| `memory` | Store, MemoryRecord, MemoryStore |
| `checkpoint` | Allowlist |
| `context` | budgets, summarization, offload, AGENTS.md |
| `middleware` | call limits, fallback, PII, structured output, tool selection |
| `agent` | Agent, AgentOptions, Session, RunResult |
| `toolcall` | tool-call parsing and markup stripping |
| `jsonschema` | documented JSON Schema subset |
| `plugin` | Manifest v1 parsing and validation |

Wire codecs preserve the Go names, including `image_url`, `runId`, and
`plugin_id`.

## Conformance

The runner reads `../spec/vectors/*.json`. A released SDK must pass every vector
and keep `spec/parity.md` current.

## License

MIT. See [LICENSE](LICENSE).
