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

## Prototype Walkthrough: Python Structured-Output Processor

This is a complete first prototype for a primary SDK. It turns one free-text
input into validated JSON and fails closed when the model omits required fields.

1. Create an application directory and install the published package:

```bash
python -m venv .venv
.venv/bin/python -m pip install "praxo-core==0.8.0"
```

2. Copy the tested schema and agent setup from
   [`language/python/examples/structured-output`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output).
   Keep the explicit policy allowlist and `StructuredOutput` middleware.

3. Run the deterministic model first:

```bash
.venv/bin/python summarize.py "Quarterly status: all checks green."
```

4. Run the deterministic rejection test. A response missing `summary` or
   `tags` must raise instead of returning partial JSON:

```bash
.venv/bin/python -m unittest test_summarize.py -v
```

5. Replace the fixture model with the OpenAI-compatible adapter only after the
   deterministic path passes. Keep the same schema and policy; do not remove the
   validation layer when moving to a real endpoint.

6. Record the package version, endpoint class, model name, schema version, and
   the command output. This is a local prototype, not a production service:
   identity, durable storage, retries, effect verification, and isolation remain
   application responsibilities.

The same pattern applies to the TypeScript, Java, C#, and Rust structured-output
examples. A different language needs its own install command, executable
example, and deterministic test before it counts as a complete path.

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
