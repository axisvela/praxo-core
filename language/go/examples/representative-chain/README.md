# Representative End-to-End Chain

This example runs one representative governed chain in Go:

```text
real model -> MCP tool -> final-argument authorization -> child delegation
           -> OpenTelemetry spans / Harmovela events -> denied edit with zero effect
```

It uses a real local Ollama model through the OpenAI-compatible adapter, an
in-memory MCP server, the OTel event sink, and a loopback Harmovela HTTP sink.
The child agent is deterministic so the delegation and denial assertions remain
stable.

## Requirements

- Go toolchain
- Ollama running at `http://127.0.0.1:11434`
- A tool-capable model, for example `qwen3.5:4b`

Start Ollama and pull the model if needed. Then run:

```bash
PRAXO_OLLAMA_MODEL=qwen3.5:4b go run .
```

PowerShell:

```powershell
$env:PRAXO_OLLAMA_MODEL = 'qwen3.5:4b'
go run .
```

Recorded output from 2026-11-17:

```text
output: DONE
effects: map[child:1 parent:1]
child calls: 2
spans: 10
events: 10
denied effects: 0
```

To run the assertions:

```bash
PRAXO_OLLAMA_MODEL=qwen3.5:4b go test -v ./...
```

The test skips when `PRAXO_OLLAMA_MODEL` is unset or the default local Ollama
endpoint is unreachable. Use `PRAXO_OLLAMA_BASE_URL` for another
OpenAI-compatible endpoint and `PRAXO_OLLAMA_API_KEY` when required.

## What It Proves

- the parent model calls the MCP `record` tool;
- the parent policy authorizes the final tool arguments;
- the parent delegates to a child with a narrower tool scope and a composed
  parent/child policy;
- OTel spans and Harmovela events are emitted for both runs;
- a middleware edit to a denied target is reauthorized, the MCP tool is not
  called, and the effect count stays unchanged.

## Boundaries

One local model, platform, MCP in-memory transport, and loopback Harmovela
server. This is not a remote MCP or Harmovela deployment, a production model
account, an independent reproduction, or a throughput/fault test. The example
does not claim exactly-once execution or general prompt-injection prevention.
