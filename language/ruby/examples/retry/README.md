# Retry

This example uses the Ruby Core SDK to retry transient model failures without
changing the agent loop.

`RetryModel` wraps another model and retries only `MODEL_UNAVAILABLE` errors, up
to a configured attempt limit. Non-retryable errors and exhausted attempts are
returned unchanged. The example is deterministic and does not sleep.

## Run the deterministic test

No endpoint is required:

```bash
ruby -I language/ruby/lib language/ruby/examples/retry/test_retry.rb
```

## Boundaries

- Retry policy belongs to the application or adapter boundary.
- Retry only errors that are safe to repeat.
- Add jitter and backoff in production; this example omits timing to stay
  deterministic.
- Do not retry side-effecting tool calls without an idempotency key.
