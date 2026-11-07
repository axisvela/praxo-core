# Retry Safety Recipe (Go)

This recipe shows the difference between retrying a transient failure and
blindly retrying a non-idempotent effect. It uses `pkg/tool.Retry` and a
status-aware application wrapper; it does not add a Core API or an effect
ledger.

**Evidence level: L4 application pattern.** It demonstrates the retry mechanics
and the application-owned status check. It does not prove target-side
idempotency, provider status semantics, or exactly-once execution. See
[EC-03](../../../docs/project/execution-correctness.md) and the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -run 'Retry|Blind|StatusAware' -v ./...
```

The tests show:

- the zero-value `RetryPolicy` performs one attempt;
- a `ShouldRetry` predicate retries only the classified transient error;
- blind retries duplicate a non-idempotent charge (the hazard);
- a status-aware wrapper queries authoritative state before retrying and keeps
  the effect count at one;
- cancellation stops the retry before another attempt.

From the repository root, `python scripts/test_go_retry_recipe.py -v` repeats the
checks in a fresh temporary module using the published package.
