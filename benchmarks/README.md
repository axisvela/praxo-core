# Agent Loop Benchmarks

These benchmarks measure PRAXO-CORE's agent-loop overhead with scripted models.
They are regression benchmarks, not cross-framework comparisons.

## Run

```bash
GOWORK=off go test ./benchmarks -bench '.*' -benchmem
```

Use `-benchtime=100x` for a quick smoke run.

## Scenarios

- `BenchmarkAgentSimple` - one model call and a final answer
- `BenchmarkAgentToolCall` - one tool call followed by a final answer
- `BenchmarkAgentParallelTools` - eight tool calls in one step
- `BenchmarkAgentContextBudget` - a 40-message session with context compaction

## Sample

On a Windows 11 machine with an Intel Core Ultra 9 185H and Go 1.26:

```text
BenchmarkAgentSimple-22           100   1964 ns/op    1393 B/op    17 allocs/op
BenchmarkAgentToolCall-22         100   4373 ns/op    4253 B/op    48 allocs/op
BenchmarkAgentParallelTools-22    100  25076 ns/op   21148 B/op   193 allocs/op
BenchmarkAgentContextBudget-22    100   2632 ns/op   14945 B/op    21 allocs/op
```

Numbers are machine-specific. Use them to detect regressions, not to compare
projects.
