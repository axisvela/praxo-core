# Structured Output Application

This example turns a directory of text files into validated JSON lines with
`StructuredOutput`. It is an application-shaped path: input files, a validated
result file, a separate failure file, and a resume mode.

## Run the deterministic application

No endpoint is required. The fixture model produces valid output for normal
input and invalid output when the text contains `invalid`.

```bash
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt

mkdir -p inputs out
printf 'Quarterly status: all checks green.\n' > inputs/quarterly.txt
printf 'invalid payload: the model omits required fields\n' > inputs/bad.txt

.venv/bin/python app.py --input-dir inputs
```

Expected summary:

```text
processed=1 skipped=0 failed=1
```

`out/results.jsonl` contains the validated record for `quarterly.txt`.
`out/errors.jsonl` contains the rejected record for `bad.txt`. Re-running with
`--resume` skips the successful input and retries the failed one:

```bash
.venv/bin/python app.py --input-dir inputs --resume
```

Expected summary:

```text
processed=0 skipped=1 failed=1
```

## Live model

Set an OpenAI-compatible endpoint and run with `--live`:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
.venv/bin/python app.py --input-dir inputs --live
```

Invalid model output is written to the error file instead of the result file.

## Deterministic test

```bash
.venv/bin/python -m unittest test_app.py -v
```

## Boundaries

- The fixture model proves application wiring, not model quality.
- The result file is a JSON-lines record, not a database or exactly-once ledger.
- Resume skips successful sources; it does not make a failed effect idempotent.
- Application identity, storage retention, tenancy, and isolation remain
  application responsibilities.
