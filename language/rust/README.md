# PRAXO-CORE Rust Core

Rust implementation of the PRAXO-CORE contract. The normative contract is
[`spec/`](../../spec/README.md); Go remains the reference implementation.

**Status:** core. The package passes all eleven conformance vector groups.
Context budgets, middleware, and the synchronous agent loop are included. The
OpenAI-compatible adapter, VFS, and plugin hosts are not yet implemented.

Package version: `0.1.2`. Supported contract: `SPEC_VERSION` `0.2.0`
(`praxo_core::SPEC_VERSION`).

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
| `jsonschema` | documented JSON Schema subset |
| `plugin` | Manifest v1 parsing and validation |

Wire codecs preserve the Go names, including `image_url`, `runId`, and
`plugin_id`.

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

The baseline is [`api/0.1.2.txt`](api/0.1.2.txt). Regenerate it with
`python api-snapshot.py` only after reviewing an intentional API change.
This is not a binary ABI or automated semver-compatibility guarantee. Serde/wire
attributes still require specification review and conformance tests; they are
not inferred from rustdoc. The gate uses `Cargo.lock` and adds no Rust dependencies.

## License

MIT. See [LICENSE](LICENSE).
