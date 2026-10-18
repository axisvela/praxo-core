# PRAXO-CORE Architecture

## Layers

```text
Agent loop
  -> model abstraction
  -> tool registry
  -> policy hook
  -> event sink
  -> memory store
  -> sandbox
  -> scheduler contract
```

## Agent Loop

1. Start a run and emit `run.started`.
2. Ask policy to authorize model generation.
3. Call the model with messages and tool specs.
4. If the model requests tools:
   - authorize each tool invocation;
   - invoke the tool;
   - append the tool result;
   - emit tool events;
   - continue.
5. On a final answer, emit `run.completed`.
6. Save a memory record if a memory store is configured.
7. Fail closed on policy denial.
8. Stop at `MaxSteps`.

## Design Rules

- Interfaces first; concrete integrations are adapters.
- No provider credentials in the framework.
- No tenant data in logs.
- No AGPL imports.
- Every exported behavior has a test.
- Event and policy errors propagate; they are not silently dropped.

## Concurrency

The framework is stateless per run. Callers may run multiple agents
concurrently. Shared adapters must provide their own synchronization.
