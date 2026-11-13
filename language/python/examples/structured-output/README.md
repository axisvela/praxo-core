# Structured Output Processor

This example uses published PyPI `praxo-core==0.6.0` to turn free text into
validated JSON with `StructuredOutput`.

## Run

```bash
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt

export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2

.venv/bin/python summarize.py "Quarterly status: all checks green."
```

Expected shape:

```json
{"title":"...","summary":"...","tags":["..."]}
```

## Deterministic test

The test uses a fake model and does not require an endpoint:

```bash
.venv/bin/python -m unittest test_summarize.py -v
```

The schema is enforced by `StructuredOutput`; invalid model output raises
`StructuredOutputError` instead of returning malformed data.
