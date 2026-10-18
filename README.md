# PRAXO-CORE

**A public, MIT-licensed agent framework for the AxisVela ecosystem.**

PRAXO-CORE provides the reusable primitives behind PRAXOVELA and other
AxisVela agents: models, tools, memory, events, scheduling, policy, sandboxing,
and the agent loop. It is a framework, not a product.

> **One-liner:** build governed agents without rebuilding the loop, provider
> abstraction, tool contracts, or memory/event boundaries.

## Framework, Not Product

| Layer | What it is | License |
| --- | --- | --- |
| `praxo-core` | Reusable agent framework and contracts (PRAXOVELA family) | MIT |
| PRAXOVELA | Runnable agent runtime product built on the framework | AGPL-3.0 |

The MIT boundary lets PRAXOVELA and external products embed the framework
without inheriting AGPL obligations. PRAXOVELA remains an AGPL product.

## Primitives

- `pkg/model` - model/provider abstraction and messages.
- `pkg/tool` - tool contracts and registry.
- `pkg/memory` - memory and context interfaces.
- `pkg/event` - event envelopes and sinks.
- `pkg/scheduler` - schedule definitions and scheduler interface.
- `pkg/policy` - decision hooks and authorization boundary.
- `pkg/sandbox` - execution sandbox interface.
- `pkg/agent` - the governed agent loop.

## Example

```go
ag := &agent.Agent{
    Model: myModel,
    Tools: tools,
    Events: sink,
    Policy: hook,
    MaxSteps: 8,
}
result, err := ag.Run(ctx, agent.Session{
    ID: "session-1",
    TenantID: "acme",
    WorkspaceID: "default",
}, "Inspect the failing test and propose a fix")
```

## Status

`0.1.0` contract baseline. The framework is extracted from PRAXOVELA's proven
runtime primitives; the API is not yet frozen.

## Documentation

- [Overview](docs/00-overview.md)
- [Architecture](docs/01-architecture.md)
- [Primitives](docs/02-primitives.md)
- [Integration](docs/03-integration.md)
- [License and provenance](docs/04-license-and-provenance.md)
- [Compatibility](docs/05-compatibility.md)
- [Roadmap](ROADMAP.md)

Internal extraction planning and product-family sequencing live in the private
PRAXOVELA-EE repository.

## License

MIT. See [LICENSE](LICENSE).
