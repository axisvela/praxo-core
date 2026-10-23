# A2A Server Adapter

`adapters/a2a` exposes a PRAXO-CORE agent as an A2A `AgentExecutor`. It uses the
official A2A Go SDK and requires Go 1.26 or newer.

```bash
go get github.com/axisvela/praxo-core/adapters/a2a@v0.1.0
```

```go
import (
    "net/http"

    "github.com/a2aproject/a2a-go/v2/a2a"
    "github.com/a2aproject/a2a-go/v2/a2asrv"
    a2aadapter "github.com/axisvela/praxo-core/adapters/a2a"
)

executor := a2aadapter.Executor{Agent: ag}
handler := a2asrv.NewHandler(executor)

mux := http.NewServeMux()
mux.Handle("/invoke", a2asrv.NewJSONRPCHandler(handler))
```

Register an agent card with `a2asrv.NewStaticAgentCardHandler` and
`a2asrv.WellKnownAgentCardPath` for discovery.

## Session Mapping

By default:

- A2A `ContextID` becomes `agent.Session.ID`
- A2A `Tenant` becomes `Session.TenantID`
- request metadata `workspaceId` becomes `Session.WorkspaceID`

Use `Executor.Session` to provide a product-specific mapping.

## Limits

- Tests cover in-process HTTP JSON-RPC and gRPC client/server round trips. The
  [Google ADK Go order-cancellation example](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
  additionally verifies external-peer JSON-RPC discovery and message exchange,
  optional bearer authentication, a two-process loopback run, and concurrent
  loopback consumers.
- The external example does not cover a deployed remote peer, gRPC external
  interoperability, cross-origin card trust, TLS termination, or deployed
  throughput/SLO behavior.
- The adapter accepts text message parts and returns one agent text message.
- It does not stream intermediate model or tool events over A2A.
- A2A cancellation maps to a canceled task status; the underlying agent run is
  canceled through its context.
- Product services still own authentication, authorization, task storage, and
  agent-card trust.

## Agent IAM Examples

The public `enterprise-autonomy` repository contains contract-level examples
that combine PRAXO-CORE A2A with NOMIVELA registration, EIDOVELA tokens, and
AEGIVELA authorization:

- [Direct A2A Agent IAM](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam/direct)
- [LIMENORA-fronted A2A Agent IAM](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam/limenora)

They use real SDK contracts with local service fakes; they are not evidence of
a live IAM deployment.
