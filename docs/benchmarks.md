# Benchmarks

PRAXO-CORE includes regression benchmarks for the governed agent loop. They
measure framework overhead with scripted models; they are not a cross-framework
performance comparison.

## Run

```bash
GOWORK=off go test ./benchmarks -bench '.*' -benchmem
```

## Scenarios

| Benchmark | What it measures |
| --- | --- |
| `BenchmarkAgentSimple` | one model call and a final answer |
| `BenchmarkAgentToolCall` | one tool call followed by a final answer |
| `BenchmarkAgentParallelTools` | eight tool calls in one step |
| `BenchmarkAgentMemoryRecall` | recall from a 20-record in-memory store |
| `BenchmarkAgentContextBudget` | a 40-message session with context compaction |

## Methodology

- The model is scripted, so benchmarks exclude network and provider latency.
- Tool execution is in-process and deterministic.
- Each benchmark resets model state before every iteration.
- Results include event, policy, and middleware plumbing.

The source and sample results live in
[`benchmarks/`](https://github.com/axisvela/praxo-core/tree/main/benchmarks).
Use the numbers to detect regressions on your own hardware, not as a comparison
between projects.
