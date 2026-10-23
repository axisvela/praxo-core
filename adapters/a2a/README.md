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

- Tests cover in-process HTTP JSON-RPC and gRPC client/server round trips; they
  do not prove interoperability with an external A2A peer.
- The adapter accepts text message parts and returns one agent text message.
- It does not stream intermediate model or tool events over A2A.
- A2A cancellation maps to a canceled task status; the underlying agent run is
  canceled through its context.
- Product services still own authentication, authorization, task storage, and
  agent-card trust.
