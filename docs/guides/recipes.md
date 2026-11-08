# Recipes

Copy-paste starting points for common integrations. Full runnable examples
live in
[`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples).

## OpenAI-Compatible Model

Works with Ollama, vLLM, and hosted OpenAI-compatible APIs. The adapter uses
only the standard library.

```go
adapter := openaicompat.Adapter{
    BaseURL: "http://localhost:11434/v1",
    Model:   "llama3.2",
}

ag, err := agent.New(agent.Options{
    Model:    adapter,
    MaxSteps: 4,
})
```

The adapter also implements `model.StreamingModel`. Set
`agent.Options.OnDelta` to receive streamed text; tool-call deltas are
aggregated into the final response. Set `IncludeUsage: true` to request
streamed token usage from compatible endpoints.

See [Quickstart](../getting-started/quickstart.md) and the
[OpenAI-compatible adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat).

## MCP Tools

Use the optional MCP module to expose MCP tools through `tool.Gateway`.

```go
client := mcpsdk.NewClient(&mcpsdk.Implementation{Name: "agent", Version: "v0.1.0"}, nil)
session, err := client.Connect(ctx, &mcpsdk.CommandTransport{
    Command: exec.Command("my-mcp-server"),
}, nil)
if err != nil {
    return err
}
defer session.Close()

tools, err := mcpadapter.NewTools(ctx, session)
if err != nil {
    return err
}
for _, item := range tools {
    registry.Register(item)
}
```

MCP authentication belongs to the client session. `NewTools` preserves each
server's input schema through `tool.SpecProvider`; the lower-level
`NewGateway`/`tool.NewGatewayTools` path carries only names and descriptions.
If you use `NewGateway` directly, call `Refresh` after the server changes its
tools. Treat every MCP server as untrusted code: run it under the same policy,
sandbox, and credential boundary as other tools, and do not pass ambient
secrets.

The same module exposes resources and prompts:

```go
resources, err := mcpadapter.ListResources(ctx, session)
contents, err := mcpadapter.ReadResource(ctx, session, "embedded:info")
prompts, err := mcpadapter.ListPrompts(ctx, session)
messages, err := mcpadapter.GetPrompt(ctx, session, "greet", map[string]string{
    "name": "Ada",
})
```

See the
[MCP adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp).

## Anthropic Messages

Use the native adapter for Anthropic models. It supports tool calls, usage, and
SSE streaming.

```go
adapter := anthropic.Adapter{
    APIKey:    os.Getenv("ANTHROPIC_API_KEY"),
    Model:     "claude-sonnet-4-5",
    MaxTokens: 1024,
}

ag, err := agent.New(agent.Options{
    Model:    adapter,
    MaxSteps: 4,
})
```

See the
[Anthropic adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/anthropic).

## Gemini generateContent

Use the native adapter for Gemini models. It supports function calls, usage, and
SSE streaming.

```go
adapter := gemini.Adapter{
    APIKey:    os.Getenv("GEMINI_API_KEY"),
    Model:     "gemini-2.5-pro",
    MaxTokens: 1024,
}

ag, err := agent.New(agent.Options{
    Model:    adapter,
    MaxSteps: 4,
})
```

See the
[Gemini adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/gemini).

## OpenTelemetry Events

Use the optional OpenTelemetry module to turn lifecycle events into spans.

```go
provider := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exporter),
)
defer provider.Shutdown(ctx)

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Events: otelsink.New(provider),
})
```

Each event becomes a `praxo.<event.type>` span with session, run, and timestamp
attributes. Adapter v0.2.0 excludes event data by default; use
`AllowedDataKeys` to opt in to individually reviewed fields. Published v0.1.0
exports all event data and requires caller-side filtering before `Emit`. See the
[OpenTelemetry sink](https://github.com/axisvela/praxo-core/tree/main/adapters/otel).
The adapter module also has a runnable, no-collector example:

```bash
cd adapters/otel
GOWORK=off go run ./example
```

## Adapter Conformance Checks

Use `pkg/conformance` to validate custom model, streaming model, tool, and
retriever adapters without provider credentials.

```go
if err := conformance.CheckModel(ctx, adapter, conformance.ModelCase{
    Request:             model.Request{Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}}},
    WantContentContains: "hello",
}); err != nil {
    return err
}
```

`CheckStreamingModel` checks stream deltas; `CheckTool` checks name, spec, and
invocation; `CheckRetriever` checks results and result limits. See the
[adapter conformance recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/conformance-go).
These are contract checks, not live-provider evidence.

## Retry Safety and Unknown Outcomes

`pkg/tool.Retry` retries failed invocations according to a policy. The zero
value performs one attempt; configure `Attempts`, `BaseDelay`, `MaxDelay`, and
`ShouldRetry` deliberately.

```go
wrapped := tool.Wrap(charge, tool.Retry(tool.RetryPolicy{
    Attempts:    3,
    ShouldRetry: func(err error) bool { return errors.Is(err, errTransient) },
}))
```

A retry is safe only when the failure is known to be harmless or the target
provides idempotency/status resolution. For a non-idempotent effect, query the
authoritative status before retrying:

```go
value, err := charge.Invoke(ctx, args)
if err != nil {
    applied, statusErr := charge.Status(ctx, args)
    if statusErr != nil {
        return nil, statusErr
    }
    if applied {
        return "charged", nil
    }
    return charge.Invoke(ctx, args)
}
```

See the [retry safety recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/retry-go).
The recipe demonstrates the duplicate-effect hazard and the status-aware
alternative; it does not provide a Core effect ledger or exactly-once guarantee.

## Event Sinks and Evidence Failures

`pkg/event` supports filtering, fan-out, and publisher adaptation. A failed sink
is not silently treated as durable evidence.

```go
sink := event.MultiSink{
    requiredAuditSink,
    event.FilterSink{
        Sink:      event.PublisherSink{Publisher: publisher},
        Predicate: func(e event.Event) bool { return e.Type == "run.completed" },
    },
}
```

`MultiSink` stops on the first failure, so order required sinks first.
`FilterSink` limits which events reach the wrapped sink; `PublisherSink` adapts
an application publisher. A sink failure before a tool call prevents the
invocation; a `run.failed` sink failure does not mask the original error. See
the [event sink recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/event-sinks-go).
The recipe does not prove durable acknowledgement, storage, or production
telemetry.

## Context Budgets and Compaction

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
[context budget recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/context-budget-go).
The recipe does not provide a general prompt-injection filter or proof of source
authenticity.

## Durable Checkpoint Store

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
[checkpoint store recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/checkpoint-store-go).
A checkpoint is a recovery hint, not a transaction or proof that an external
effect committed; concurrent-write control, retention, encryption, and tenant
authority remain application responsibilities.

## Structured Output and Tool Schema

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
[structured output recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/structured-output-go).
The recipe does not prove that a provider honors `ResponseFormat`.

## VFS and Path Containment

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
[VFS containment recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/vfs-containment-go).
These are local host controls, not container/VM isolation or deployment-level
containment; independent review and OS/network isolation remain external.

## Provider Fallback

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
[provider fallback recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/provider-fallback-go).
Provider credentials, timeouts, retry budgets, and SLA evidence remain
application or gateway responsibilities.

## Plugin Lifecycle

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
[plugin lifecycle recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/plugin-lifecycle-go)
and [plugin trust](../security/plugin-trust.md). The recipe is a contract
exercise, not process/WASM isolation or manifest trust evidence.

## Delegated Subagents

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
[multi-agent recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/multi-agent-go)
and the [multi-agent guide](multi-agent.md). The manager is local task
coordination, not a durable remote worker or cross-process recovery service.

## Streaming

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
[streaming recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/streaming-go).
Provider-specific tool-call delta aggregation and production telemetry remain
adapter or gateway responsibilities.

## Workspace Session Contract (Evaluation)

The `adapters/workspace` module evaluates a provider-neutral session contract
without promoting it to `pkg/`. A session combines `sandbox.Sandbox`,
`vfs.Backend`, file transfer, and lifecycle methods; `Pauser` and `Snapshotter`
are optional capabilities discovered by type assertion.

```go
provider := fake.NewProvider()
if err := conformance.CheckProvider(ctx, provider, conformance.Case{
    Command:            []string{"echo", "ok"},
    WantStdoutContains: "echo ok",
    Path:               "nested/file.txt",
    Content:            []byte("conformance"),
}); err != nil {
    return err
}
```

The shared conformance suite checks create, file transfer, VFS operations,
command execution, attach, optional pause/resume, close, and attach-after-close
rejection. The evaluation `profile` package also validates `state`, `local`, and
`sandbox` runtime profiles before returning tools: state profiles never expose
execution, local execution must be explicit, and sandbox upload/download/pause
capabilities require a matching session. See the
[workspace session example](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace/example),
the [runtime profile implementation](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace/profile),
and the [workspace/session evaluation](../reference/workspace-session.md). The
fake provider is not an isolation boundary, no live provider is used, and the
contract is not a Core API commitment.

## NOETIVELA

NOETIVELA is the AxisVela inference fabric. Wrap its governed chat API in a
`model.Model` adapter.

```go
adapter := noetivelaadapter.Adapter{
    Client: sdk.New("http://localhost:1826"),
    Policy: "legal-confidential-v2",
    ContractFunc: func(model.Request) *sdk.Contract {
        return &sdk.Contract{
            Task:     "status_lookup",
            Modality: []string{"text"},
        }
    },
}
```

The Core exposes text content, not tool calls. For tool calling, use a custom
HTTP adapter that preserves tool-call fields. See the
[NOETIVELA SDK example](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/noetivela).

## Mnemovela

Mnemovela is the Agent Cognition Runtime. Its JSON-RPC transport backs
`memory.Store`.

```go
transport := jsonrpc.New("http://localhost:8080")
store := mnemovelaadapter.Store{
    Client: mnemovela.New(transport),
    Branch: "main",
}

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Memory: store,
    Recall: true,
})
```

See the
[Mnemovela Core example](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/mnemovela).

## GNOSIVELA

GNOSIVELA grounding maps to `retriever.Retriever`.

```go
adapter := gnosivelaadapter.Retriever{
    Client:    gnosivela.New("http://localhost:8080"),
    Principal: "user:demo",
    Purpose:   "status_lookup",
    Budget:    1200,
}

documents, err := adapter.Retrieve(ctx, "current status", 8)
```

GNOSIVELA does not yet publish a `v3` semver tag for this module path; the
example module pins a pseudo-version from `master`. See the
[GNOSIVELA Core example](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/gnosivela).

## AEGIVELA Policy

Map AEGIVELA policy evaluation to `policy.Hook`.

```go
hook := aegivelaadapter.Hook{
    Client: pepsdk.NewClient("https://aegivela.example.com", http.DefaultClient),
    Route: pepsdk.Route{
        Audience:  "agent",
        Action:    "tool:invoke",
        Scope:     []string{"tool:invoke"},
        Kind:      "tool",
        Reference: "lookup",
    },
    Input: pepsdk.AuthorizationInput{
        Mode:              pepsdk.ModeSystemAPI,
        WorkloadAssertion: "...",
    },
}
```

The hook allows only an exact `allow` outcome; every other outcome is denied.
Load `WorkloadAssertion` from your secret manager at runtime instead of
hardcoding it, and keep `Route` values static. See the
[AEGIVELA Core example](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/aegivela).

## LIMENORA Gateway

Map tool names to governed outbound requests through the LIMENORA network
gateway.

```go
gateway := limenoraadapter.Gateway{
    Client: proxyEgress,
    Tools: map[string]limenoraadapter.Route{
        "lookup": {
            URL:         "https://api.example.com/status",
            Method:      "POST",
            Description: "Look up status",
        },
    },
    Ctx: sdk.AuthzContext{
        TenantID:    "acme",
        WorkspaceID: "default",
        ActorID:     "agent-1",
    },
}
```

Keep routes static and allowlisted. Do not derive `URL`, `Method`, or headers
from model output; let LIMENORA enforce the egress policy. See the
[LIMENORA Core example](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/limenora).

## Harmovela Events

Publish lifecycle events to Harmovela's HTTP API through `event.Sink`.

```go
sink := harmovela.Sink{
    BaseURL: "http://127.0.0.1:8790/aep/api",
    Source:  "praxo-core",
}

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Events: sink,
})
```

The sink emits `spec_version`, `id`, `type`, `source`, `created_at`, and a
payload containing session, run, and event data. Scrub or omit secrets,
credentials, and PII before emitting, or use an event sink that enforces
redaction. See the
[Harmovela adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/harmovela).

## A2A Server

Expose a PRAXO-CORE agent as an A2A server executor.

```go
executor := a2aadapter.Executor{Agent: ag}
handler := a2asrv.NewHandler(executor)

mux := http.NewServeMux()
mux.Handle("/invoke", a2asrv.NewJSONRPCHandler(handler))
```

A2A `ContextID` maps to the session ID by default; use `Executor.Session` for a
custom mapping. The
[Google ADK Go order-cancellation example](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
uses an external A2A consumer to discover this server through its agent card and
call it over JSON-RPC. It covers approval, business denial, remote failure,
timeout, optional bearer authentication, a two-process loopback run, concurrent
consumers, loopback TLS termination, and cross-origin agent-card rejection with
deterministic fixtures. It does not prove a deployed remote peer, external gRPC,
deployed TLS/identity, or deployed throughput/SLO behavior. The
`enterprise-autonomy` repository also has
[direct](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam/direct)
and [LIMENORA-fronted](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam/limenora)
Agent IAM contract examples with NOMIVELA, EIDOVELA, AEGIVELA, Google ADK, and
PRAXO-CORE. See the
[A2A adapter](https://github.com/axisvela/praxo-core/tree/main/adapters/a2a).

## RHEOVELA Workflow

Map an agent session to a RHEOVELA workflow instance. RHEOVELA owns graph and
subgraph execution; PRAXO-CORE supplies the agent node/session boundary.

```go
runner := rheovelaadapter.Runner{
    Client:    rheovela.NewClient("http://127.0.0.1:8080"),
    Workflow:  "agent",
    ProjectID: "proj",
    Actor:     "agent-1",
}

instance, err := runner.Start(ctx, session)
err = runner.Step(ctx, instance.InstanceID, "advance", "review")
audit, err := runner.Audit(ctx, instance.InstanceID)
```

See the
[RHEOVELA Core example](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk/rheovela).

## Sandbox and Policy

Authorize before execution and keep high-risk commands behind
`sandbox.Sandbox`.

```go
func commandArgs(value any) ([]string, bool) {
    switch v := value.(type) {
    case []string:
        return v, true
    case []any:
        out := make([]string, len(v))
        for i, item := range v {
            text, ok := item.(string)
            if !ok {
                return nil, false
            }
            out[i] = text
        }
        return out, true
    default:
        return nil, false
    }
}

command := []string{"go", "version"}

hook := policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
    requested, ok := commandArgs(action.Arguments["command"])
    if action.ToolName != "exec" || !ok || len(requested) != 2 ||
        requested[0] != "go" || requested[1] != "version" {
        return policy.Decision{Allowed: false, Reason: "command is not allowlisted"}, nil
    }
    return policy.Decision{Allowed: true}, nil
})

decision, err := hook.Authorize(ctx, policy.Action{
    Kind:      "sandbox",
    ToolName:  "exec",
    Arguments: map[string]any{"command": command},
})
if err != nil {
    return err
}
if !decision.Allowed {
    return fmt.Errorf("sandbox: %s", decision.Reason)
}
result, err := runner.Run(ctx, sandbox.Spec{Timeout: 5 * time.Second}, command)
```

Pass the same command to authorization and execution. `sandbox.Sandbox` is an
interface: this example gates host execution but does not provide OS-level
isolation. Keep the allowlist static and do not build it from model output. See
the
[sandbox example](https://github.com/axisvela/praxo-core/tree/main/examples/sandbox).

## Governed Workspace Demo

The governed workspace demo is a deterministic, no-API-key path through
read-only tools, write approval, denial, and policy rejection with an event
trace. It uses a scripted model and does not claim real model behavior.

```bash
GOWORK=off go run ./examples/governed-workspace -mode read
GOWORK=off go run ./examples/governed-workspace -mode write
GOWORK=off go run ./examples/governed-workspace -mode deny
GOWORK=off go run ./examples/governed-workspace -mode escape
```

See the
[governed workspace demo](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace).

## Reference Workspace Agent

The reference app combines the OpenAI-compatible adapter, confined VFS tools,
policy, memory, events, and a context budget.

```bash
GOWORK=off go run ./examples/reference -workspace ./workspace
```

The example policy allows only `model.generate` and `fs.*` tool calls, and the
VFS backend confines paths to the workspace. See the
[reference app](https://github.com/axisvela/praxo-core/tree/main/examples/reference).
