# Representative End-to-End Chain Tutorial

This tutorial runs one complete governed chain with a real local model:

```text
Ollama model
  -> MCP record tool
  -> final-argument authorization
  -> governed child delegation
  -> OTel spans and Harmovela events
  -> edited denial with zero effects
```

The runnable project is
[`examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/examples/representative-chain).
It uses Go module `github.com/axisvela/praxo-core/v2@v2.9.0`, an in-memory MCP
server, a loopback Harmovela sink, and a local Ollama endpoint.

## Prerequisites

- Go 1.25 or newer
- Ollama running at `http://127.0.0.1:11434`
- A tool-capable Ollama model; this tutorial uses `qwen3.5:4b`

```bash
ollama pull qwen3.5:4b
```

Verify the endpoint before running the chain:

```bash
curl http://127.0.0.1:11434/api/tags
```

## Run

```bash
cd examples/representative-chain
export PRAXO_OLLAMA_MODEL=qwen3.5:4b
go run .
```

PowerShell:

```powershell
cd examples\representative-chain
$env:PRAXO_OLLAMA_MODEL = "qwen3.5:4b"
go run .
```

The default endpoint is `http://127.0.0.1:11434/v1`. Set
`PRAXO_OLLAMA_BASE_URL` for another OpenAI-compatible endpoint and
`PRAXO_OLLAMA_API_KEY` when the endpoint requires a key.

Recorded output from 2026-11-17:

```text
output: DONE
effects: map[child:1 parent:1]
child calls: 2
spans: 10
events: 10
denied effects: 0
```

## Run the Assertions

```bash
PRAXO_OLLAMA_MODEL=qwen3.5:4b go test -v ./...
```

Expected:

```text
--- PASS: TestRepresentativeChain
--- PASS: TestDenialZeroEffect
```

The test skips when `PRAXO_OLLAMA_MODEL` is unset. The denial test runs without
a model and checks that a middleware edit is reauthorized, the MCP tool is not
called, and the effect count stays zero.

## What Each Step Proves

| Step | Evidence |
| --- | --- |
| Real model | The parent uses the OpenAI-compatible Ollama endpoint, not a fixture |
| MCP tool | The model calls the MCP `record` tool with `target=parent` |
| Final authorization | The parent policy authorizes the tool name and final arguments |
| Delegation | The parent calls an application-level `delegate` tool; the child scope is `record` only, with parent and child policy composed |
| OTel | The in-memory exporter receives `praxo.run.started`, `praxo.tool.call`, and `praxo.run.completed` spans |
| Harmovela | A loopback HTTP sink receives the same lifecycle events |
| Denial | A middleware edit changes `target` to `blocked`; reauthorization denies it and the MCP tool is not invoked |

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `connection refused` | Start Ollama and confirm `http://127.0.0.1:11434/api/tags` responds |
| `model not found` | Pull the exact model id and set `PRAXO_OLLAMA_MODEL` |
| No tool call | Use a tool-capable model and keep the explicit prompt in the example |
| Go checksum mismatch for `v2.9.0` | Clear the stale module-cache entry and re-download; do not edit `go.sum` manually |
| Harmovela or OTel assertions fail | Confirm the event sink wiring; no external collector is required |

Clear a stale Go module cache entry without bypassing module authentication:

```bash
go clean -modcache
```

## Boundaries

This is local integration evidence, not a production deployment. It uses one
local model, platform, in-memory MCP transport, and loopback Harmovela server.
The child model is deterministic. It does not prove remote MCP or Harmovela
operation, independent reproduction, throughput, fault recovery, exactly-once
execution, or general prompt-injection prevention.

Deterministic counterparts exist for all other Core SDK languages under their
representative-chain examples or native test suites. They cover the same MCP,
authorization, delegation, OTel/Harmovela, and denial seams without a live
provider; see the [verification evidence](../project/verification-evidence.md)
for the recorded set and its limits.

See the [verification evidence](../project/verification-evidence.md) and
[multi-agent patterns](multi-agent.md) for the wider evidence and delegation
boundaries.
