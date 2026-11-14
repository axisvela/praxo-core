# Live Model Golden Path

The Go project lives in [`go/`](go/). Other language projects live under
`language/<lang>/language/go/examples/live-model`, so the dedicated language mirrors include
them. Each example:

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
cd language/go/examples/live-model/go
go run .
```

## Python

```bash
cd language/python/examples/live-model
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python live_starter.py
```

## TypeScript

```bash
cd language/typescript/examples/live-model
npm install
npm start
```

## Java

```bash
cd language/java/examples/live-model
mvn -q compile exec:java
```

## Deterministic allow/deny check

The live path proves model/tool integration. For a deterministic denial check
that must produce no tool effect, run the corresponding consumer starter after
the live example:

- [`language/go/examples/consumer-go`](../consumer-go)
- [`language/python/examples/consumer`](../../../python/examples/consumer)
- [`language/typescript/examples/consumer`](../../../typescript/examples/consumer)
- [`language/java/examples/consumer`](../../../java/examples/consumer)

These checks are intentionally separate from the live model path.
