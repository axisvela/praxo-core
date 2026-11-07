# Streaming Recipe (Go)

This recipe shows text delta streaming, typed run-stream parts, stream errors,
and cancellation with a deterministic `model.StreamingModel`. It needs no
provider credentials or network service.

**Evidence level: L1 contract recipe.** It demonstrates the configured streaming
path. It does not prove live provider streaming, tool-call delta aggregation
across providers, or production telemetry. See the
[stream reference](../../../docs/reference/events.md) and the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -v ./...
```

The tests show:

- `OnDelta` receives fragments in order and the final response still carries the
  complete content;
- a streaming-model error is returned from the run;
- cancellation stops further deltas and returns `context.Canceled`;
- `OnStream` receives typed projections such as `values` and `messages`.

From the repository root, `python scripts/test_go_streaming_recipe.py -v`
repeats the checks in a fresh temporary module using the published package.
