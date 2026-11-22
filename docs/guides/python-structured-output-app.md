# Python Structured Output Application

This tutorial builds a small batch application that turns text files into
validated JSON, records rejected model output separately, and resumes without
reprocessing successful inputs. It uses the Python Core and the
`StructuredOutput` middleware.

The example lives at
[`language/python/examples/structured-output-app`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output-app).
It is application-shaped: input directory, result file, error file, deterministic
fixture model, optional live model, and resume mode.

## What You Build

For every `*.txt` file in an input directory, the application:

1. asks the model for JSON with `title`, `summary`, and `tags`;
2. validates the response against a schema;
3. appends validated records to `out/results.jsonl`;
4. appends rejected responses to `out/errors.jsonl`; and
5. skips already successful inputs when `--resume` is set.

A rejected model response does not become result data. The failure is recorded
with its source file and error type.

## Setup

```bash
cd language/python/examples/structured-output-app
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

For a source checkout without installing the published package, set
`PYTHONPATH` to the repository's Python Core:

```bash
export PYTHONPATH=language/python
```

## Run the Deterministic Application

Create two inputs:

```bash
mkdir -p inputs
printf 'Quarterly status: all checks green.\n' > inputs/quarterly.txt
printf 'invalid payload: the model omits required fields\n' > inputs/invalid.txt
```

Run the fixture model:

```bash
.venv/bin/python app.py --input-dir inputs
```

Expected summary:

```text
processed=1 skipped=0 failed=1
```

`out/results.jsonl` contains one validated record:

```json
{"result":{"summary":"Quarterly status: all checks green.","tags":["triage"],"title":"Quarterly status: all checks green."},"source":"quarterly.txt"}
```

`out/errors.jsonl` records the invalid response instead of accepting it:

```json
{"detail":"agent: structured output validation failed: schema: $.summary: required field missing, $.tags: required field missing","error":"StructuredOutputError","source":"invalid.txt"}
```

The fixture model deliberately returns a partial object when the input contains
`invalid`, so the failure path runs without a live endpoint.

## Resume

Run the same command with `--resume`:

```bash
.venv/bin/python app.py --input-dir inputs --resume
```

Expected summary:

```text
processed=0 skipped=1 failed=1
```

The successful input is skipped. The failed input is retried because it never
produced a result record. Resume is a workflow convenience, not an exactly-once
or effect-ledger guarantee.

## Use a Live Model

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
.venv/bin/python app.py --input-dir inputs --live
```

Provide credentials through the application environment. Keep provider keys
outside the input directory and out of committed files.

## Failure Handling

- Schema validation errors go to `out/errors.jsonl`; they are not written as
  results.
- The process exits nonzero when any input fails, so a scheduler can surface the
  condition.
- A failed input is retried on the next `--resume` run.
- Transport failures are recorded the same way as validation failures, but they
  do not prove that a remote effect did or did not happen. Add application
  reconciliation before retrying side-effecting tools.

## Recorded Run

On 2026-11-22 the deterministic path was run from a source checkout with
`PYTHONPATH=language/python`:

```text
processed=1 skipped=0 failed=1
processed=0 skipped=1 failed=1
```

The first run wrote one result and one error. The resume run skipped the success
and retried the failure. This is maintainer-run integration evidence for the
example, not an external consumer or production deployment.

## Boundaries

- The fixture model proves application wiring, not model quality.
- JSON-lines files are a teaching record, not a database, queue, or lease.
- Validation proves that the returned object matches the declared subset schema;
  it does not make the model truthful.
- Identity, tenancy, retention, isolation, and effect reconciliation remain
  application responsibilities.

## Next Steps

- Replace the fixture model with an application-owned provider adapter.
- Add a real store or queue if multiple workers must process inputs.
- Add authentication and tenant scoping before accepting untrusted input.
- Apply the [consumer test template](consumer-test-template.md) to the
  application repository and record the exact package version.
