# Published Module Consumer Test

This independent module consumes released tags, not the repository checkout.
Run it with `GOWORK=off`; it deliberately has no local `replace` directives.

This is the historical Core `2.5.0` and adapter compatibility baseline, not a
check of the current recommended Core package. The separate
[Go consumer starter](../../language/go/examples/consumer-go/README.md) pins Core `2.7.0`
and verifies its allow/deny integration path in the `current-go-consumer` CI job.

```sh
GOWORK=off go test -mod=readonly ./...
GOWORK=off go vet -mod=readonly ./...
GOWORK=off go build -mod=readonly ./...
```

The tests compile the published adapter interfaces, execute a deterministic
agent run, exercise the published subagent `Wait`/`Prune` lifecycle including
concurrent waiters across pruning, and check the dependency graph for unexpected
replacements or version changes. They do not call live providers or validate
production integrations.
