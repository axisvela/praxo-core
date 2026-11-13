# Live Model Golden Path

This directory is a minimal published-package path for connecting PRAXO-CORE to
a real OpenAI-compatible model. Each example:

- installs a published package instead of a repository checkout;
- registers one low-risk `get_time` tool;
- authorizes only `get_time`;
- prints the model result.

Use a local Ollama server or any OpenAI-compatible endpoint.

## Environment

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
# export PRAXO_API_KEY=...   # only for hosted endpoints
```

PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "llama3.2"
```

## Go

```bash
cd go
go run .
```

## Python

```bash
cd python
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python live_starter.py
```

## TypeScript

```bash
cd typescript
npm install
npm start
```

## Java

```bash
cd java
mvn -q compile exec:java
```

## Deterministic allow/deny check

The live path proves model/tool integration. For a deterministic denial check
that must produce no tool effect, run the corresponding consumer starter after
the live example:

- [`examples/consumer-go`](../consumer-go)
- [`examples/consumer-python`](../consumer-python)
- [`examples/consumer-typescript`](../consumer-typescript)
- [`examples/consumer-java`](../consumer-java)

These checks are intentionally separate from the live model path.
