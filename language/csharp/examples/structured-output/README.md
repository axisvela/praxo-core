# Structured Output Processor

This example uses published NuGet `Praxo.Core==0.6.0` to turn free text into
validated JSON with `StructuredOutput`.

## Run

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
dotnet run -- "Quarterly status: all checks green."
```

Expected shape:

```json
{"title":"...","summary":"...","tags":["..."]}
```

## Deterministic check

The `--test` mode uses a fake model and does not require an endpoint:

```bash
dotnet run -- --test
```

The schema is enforced by `StructuredOutput`; invalid model output raises
`PraxoException` instead of returning malformed data.
