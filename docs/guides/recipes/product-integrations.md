# Product Integrations

Optional AxisVela product and protocol integration recipes.

## Workspace Session Contract (Evaluation) {#workspace-session-contract-evaluation}

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
and the [workspace/session evaluation](../../reference/workspace-session.md). The
fake provider is not an isolation boundary, no live provider is used, and the
contract is not a Core API commitment.

## NOETIVELA {#noetivela}

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
[NOETIVELA SDK example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/noetivela).

## Mnemovela {#mnemovela}

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

Supplying a `memory.Store` alone does not inject records; `Recall: true` is
required. Other Core SDKs currently do not auto-recall.

Recalled records are injected as untrusted historical user data, not as system
instructions, and the recall block names the frame and source when available.
Memory content must not be able to raise its own instruction authority. See the
[Mnemovela Core example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/mnemovela).

## GNOSIVELA {#gnosivela}

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
[GNOSIVELA Core example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/gnosivela).

## AEGIVELA Policy {#aegivela-policy}

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
[AEGIVELA Core example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/aegivela).

## LIMENORA Gateway {#limenora-gateway}

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
[LIMENORA Core example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/limenora).

## Harmovela Events {#harmovela-events}

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

## A2A Server {#a2a-server}

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

## RHEOVELA Workflow {#rheovela-workflow}

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
[RHEOVELA Core example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/ecosystem-sdk/rheovela).
