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
