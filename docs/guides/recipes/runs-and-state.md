# Runs And State

Context, checkpoints, structured output, cancellation, and run-scoped state.

## Context Budgets and Compaction {#context-budgets-and-compaction}

`pkg/agent/context` provides a deterministic budget pass and an optional model
summarizer. The first System message is preserved; if it cannot fit, compaction
fails instead of silently dropping mandatory instructions.

```go
budget := agentcontext.ContextBudget{MaxTokens: 12000, KeepRecent: 6}
compacted, ok := budget.Compact(messages)
if !ok {
    return agentcontext.ErrContextBudget
}
```

`ModelSummarizer` replaces older messages with a summary before the deterministic
pass; a summary-model failure falls back to deterministic compaction instead of
aborting the run. See the
[context budget recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/context-budget-go).
The recipe does not provide a general prompt-injection filter or proof of source
authenticity.

## Durable Checkpoint Store {#durable-checkpoint-store}

`pkg/checkpoint` defines the store contract; the application owns durable
storage. A file-backed teaching store can write a temporary file, `Sync`, and
`Rename` so a partial write is not exposed:

```go
store, err := OpenFileStore(checkpointDir)
if err != nil {
    return err
}
if err := store.Save(ctx, &checkpoint.Checkpoint{
    ID: checkpointID, SessionID: sessionID, RunID: runID, Status: "completed",
}); err != nil {
    return err
}
```

The recipe also ignores leftover `.tmp` files, reloads after reopening, and
supports tenant-scoped loads. See the
[checkpoint store recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/checkpoint-store-go).
A checkpoint is a recovery hint, not a transaction or proof that an external
effect committed; concurrent-write control, retention, encryption, and tenant
authority remain application responsibilities.

## Structured Output and Tool Schema {#structured-output-and-tool-schema}

`pkg/tool/jsonschema` validates a deliberately small JSON Schema subset for
model output and tool arguments. Keep application-side validation even when a
provider supports `ResponseFormat`.

```go
schema, err := jsonschema.FromJSON(schemaJSON)
if err != nil {
    return err
}
if errors := schema.Validate(value); len(errors) != 0 {
    return fmt.Errorf("invalid structured output: %+v", errors)
}
```

The same schema can be carried in `model.ResponseFormat` and used to reject
tool arguments before invoking the tool. Unsupported keywords such as `$ref`,
composition, `additionalProperties`, and `format` are ignored; use a full JSON
Schema library when those are required. See the
[structured output recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/structured-output-go).
The recipe does not prove that a provider honors `ResponseFormat`.

## VFS and Path Containment {#vfs-and-path-containment}

`pkg/vfs/localfs` confines virtual paths to a root and uses `os.Root` for actual
file operations after `policy.PathChecker` authorization. `policy.PathChecker`
is deny-by-default and resolves symlinks before comparing paths.

```go
backend, err := localfs.New(workspaceRoot)
if err != nil {
    return err
}
if err := backend.Write(ctx, "notes/a.txt", data); err != nil {
    return err
}
```

Traversal, NUL-byte paths, root deletion, and symlinks that escape the root are
rejected. A read-only grant denies writes. See the
[VFS containment recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/vfs-containment-go).
These are local host controls, not container/VM isolation or deployment-level
containment; independent review and OS/network isolation remain external.

## Provider Fallback {#provider-fallback}

A fallback model wrapper can try a secondary provider when the primary fails,
without hiding caller cancellation.

```go
type FallbackModel struct {
    Primary        model.Model
    Secondary      model.Model
    ShouldFallback func(error) bool
}

func (m FallbackModel) Generate(ctx context.Context, req model.Request) (model.Response, error) {
    response, err := m.Primary.Generate(ctx, req)
    if err == nil {
        return response, nil
    }
    if ctxErr := ctx.Err(); ctxErr != nil {
        return model.Response{}, ctxErr
    }
    if m.ShouldFallback != nil && !m.ShouldFallback(err) {
        return model.Response{}, err
    }
    return m.Secondary.Generate(ctx, req)
}
```

Use an explicit `ShouldFallback` predicate so a non-retryable request is not
sent to a second provider. See the
[provider fallback recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/provider-fallback-go).
Provider credentials, timeouts, retry budgets, and SLA evidence remain
application or gateway responsibilities.

## Plugin Lifecycle {#plugin-lifecycle}

`pkg/plugin.Lifecycle` is the guarded per-instance state machine. Only ACTIVE
accepts invocations; every other state is fail-closed.

```go
lifecycle := plugin.NewLifecycle()
for _, next := range []plugin.State{
    plugin.StateValidated, plugin.StateLoaded, plugin.StateActive,
} {
    if err := lifecycle.Transit(next); err != nil {
        return err
    }
}
if err := lifecycle.Acquire(); err != nil {
    return err
}
defer lifecycle.Release()
```

Drain waits for in-flight calls with a bounded context, Revoke moves
ACTIVE to UNLOADED, and Quarantine is terminal. See the
[plugin lifecycle recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/plugin-lifecycle-go)
and [plugin trust](../../security/plugin-trust.md). The recipe is a contract
exercise, not process/WASM isolation or manifest trust evidence.

## Delegated Subagents {#delegated-subagents}

`pkg/agent/delegation.SubagentManager` launches asynchronous child tasks over a
`SubagentRunner`, tracks queued/running/terminal state, and supports optional
mid-flight steering.

```go
manager := delegation.NewSubagentManager(runner)
task, err := manager.Launch(ctx, delegation.SubagentRequest{
    ParentSessionID: "parent", AgentID: "researcher", Prompt: "inspect the issue",
})
if err != nil {
    return err
}
finished, err := manager.Wait(ctx, task.ID)
```

Only running tasks accept updates; cancellation is terminal; `List` filters by
parent session; `Prune` removes terminal tasks only. See the
[multi-agent recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/multi-agent-go)
and the [multi-agent guide](../multi-agent.md). The manager is local task
coordination, not a durable remote worker or cross-process recovery service.

## Streaming {#streaming}

When `OnDelta` is configured and the model implements `model.StreamingModel`,
the agent calls `GenerateStream` and forwards text fragments as they arrive. The
final response still carries the complete content and any tool calls.

```go
ag, err := agent.New(agent.Options{
    Model:    streamingModel,
    MaxSteps: 4,
    OnDelta:  func(delta string) { fmt.Fprint(w, delta) },
    OnStream: func(part agent.StreamPart) error {
        // typed projections: values, updates, messages, tasks, debug, checkpoint
        return nil
    },
})
```

A streaming error is returned from the run, and cancellation stops further
deltas. See the
[streaming recipe](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/streaming-go).
Provider-specific tool-call delta aggregation and production telemetry remain
adapter or gateway responsibilities.
