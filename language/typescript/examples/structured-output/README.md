# Structured Output Processor

This example uses published npm `@axisvela/praxo-core@0.5.0` to turn free text
into validated JSON with `StructuredOutput`.

## Run

```bash
npm install
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
npm start -- "Quarterly status: all checks green."
```

Expected shape:

```json
{"title":"...","summary":"...","tags":["..."]}
```

## Deterministic test

The test uses a fake model and does not require an endpoint:

```bash
npm test
```

The schema is enforced by `StructuredOutput`; invalid model output raises
`StructuredOutputError` instead of returning malformed data.
