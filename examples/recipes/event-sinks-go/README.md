# Event Sinks and Evidence Failures Recipe (Go)

This recipe shows how the Core event boundary behaves when a sink is filtered,
fans out, delegates to a publisher, fails before a tool invocation, or fails
while reporting a failed run. It uses `pkg/event` and the public `agent.Options`
without external services.

**Evidence level: L4 application pattern and L1 contract checks.** It
demonstrates configured sink behavior; it does not prove durable event storage,
acknowledgement, or production telemetry. See
[EC-10](../../../docs/project/execution-correctness.md) and the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -run 'Sink|Publisher|Agent' -v ./...
```

The tests show:

- `FilterSink` forwards only matching event types;
- `MultiSink` stops when a sink fails, so later sinks do not run;
- `PublisherSink` delegates to an application publisher;
- a `tool.call` sink failure prevents the tool invocation;
- a `run.failed` sink failure does not mask the original model error.

From the repository root, `python scripts/test_go_event_sink_recipe.py -v`
repeats the checks in a fresh temporary module using the published package.
