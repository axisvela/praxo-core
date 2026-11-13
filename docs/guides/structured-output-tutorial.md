# Structured Output by Language

This tutorial turns free text into validated JSON with `StructuredOutput`. The
same schema is implemented in five published-package examples:

- [Python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output)
- [TypeScript](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/structured-output)
- [Java](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/structured-output)
- [C#](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/structured-output)
- [Rust](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/structured-output)

Each example validates `title`, `summary`, and `tags` before returning the model
output. Invalid output fails instead of returning malformed data.

## Schema

```json
{
  "type": "object",
  "required": ["title", "summary", "tags"],
  "properties": {
    "title": { "type": "string" },
    "summary": { "type": "string" },
    "tags": { "type": "array", "items": { "type": "string" } }
  }
}
```

## Run by Language

### Python

```bash
cd language/python/examples/structured-output
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python summarize.py "Quarterly status: all checks green."
```

Deterministic test:

```bash
.venv/bin/python -m unittest test_summarize.py -v
```

### TypeScript

```bash
cd language/typescript/examples/structured-output
npm install
npm start -- "Quarterly status: all checks green."
npm test
```

### Java

```bash
cd language/java/examples/structured-output
mvn -q compile exec:java -Dexec.args="Quarterly status: all checks green."
mvn -q test
```

### C#

```bash
cd language/csharp/examples/structured-output
dotnet run -- "Quarterly status: all checks green."
dotnet run -- --test
```

### Rust

```bash
cd language/rust/examples/structured-output
cargo run
```

The deterministic check validates a valid summary and rejects output that
omits required fields.

## Live Endpoint

The runnable commands use an OpenAI-compatible endpoint:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
# export PRAXO_API_KEY=...   # hosted endpoints only
```

On PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "llama3.2"
```

## What the Examples Prove

- the package is installed from a registry;
- the model adapter is configured from environment variables;
- `StructuredOutput` validates the final JSON against the schema;
- a fake-model test verifies the integration without a live endpoint.

They do not prove model quality, schema completeness, provider structured-output
support, or production behavior. Keep the final schema validation in the
application even when a provider supports structured output natively.

## Related

- [Examples](../getting-started/examples.md)
- [Live Model Golden Path](../getting-started/live-model-golden-path.md)
- [Application integration checklist](application-integration-checklist.md)
- [Consumer test template](consumer-test-template.md)
