# Rust Live Model

This source-mode example connects the Rust Core to an OpenAI-compatible endpoint
and registers one low-risk `get_time` tool.

It uses the optional `http-ureq` feature and the `OpenAICompatible` adapter. The
published `praxo-core==0.8.0` crate predates this feature; use the repository
source until the next Rust release.

## Run

```bash
cd language/rust/examples/live-model
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=qwen3.5:4b
# export PRAXO_API_KEY=...   # only for hosted endpoints
cargo run
```

PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
cargo run
```

`qwen3.5:4b` is a small local option; use any installed OpenAI-compatible model
name instead if needed. The example authorizes only `get_time`; every other
tool call is denied by policy.

## Feature

`http-ureq` is optional. Without it, the Core keeps its dependency-free default
build and the `openai_compat` module only provides the SSE stream parser. With
the feature enabled, `OpenAICompatible::with_ureq` provides the HTTP client.
Hosted HTTPS endpoints require the `native-tls` feature path enabled by
`http-ureq`.

The example is an integration starting point, not a production security
profile. Identity, durable approvals, isolation, and effect reconciliation
remain the application's responsibility.
