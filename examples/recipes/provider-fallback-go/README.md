# Provider Fallback Recipe (Go)

This recipe wraps two `model.Model` implementations and falls back to the
secondary model only when the primary fails and the caller has not cancelled.
It works with deterministic fixtures and needs no provider credentials.

**Evidence level: L4 application pattern.** It demonstrates one fallback policy.
It is not a provider SLA, failover service, or production capacity claim. See
the [test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -v ./...
```

The tests show:

- the primary model is used when it succeeds;
- the secondary model is used when the primary fails;
- a `ShouldFallback` predicate can keep the primary error without trying the
  secondary;
- the fallback error is returned when both models fail;
- context cancellation stops the fallback instead of retrying another provider;
- a nil primary model uses the secondary directly.

Keep provider-specific timeouts, retry budgets, credentials, and observability in
the application or gateway. From the repository root,
`python scripts/test_go_provider_fallback_recipe.py -v` repeats the checks in a
fresh temporary module using the published package.
