# Retry

This example uses published PyPI `praxo-core==0.6.0` to retry transient model
failures without changing the agent loop.

The model middleware retries only `MODEL_UNAVAILABLE` errors, up to a configured
attempt limit. Non-retryable errors and exhausted attempts are returned
unchanged. The example is deterministic and does not sleep.

## Run the deterministic test

No endpoint is required:

```bash
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest test_retry.py -v
```

## Boundaries

- Retry policy belongs to the application or adapter boundary.
- Retry only errors that are safe to repeat.
- Add jitter and backoff in production; this example omits timing to stay
  deterministic.
- Do not retry side-effecting tool calls without an idempotency key.
