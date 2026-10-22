# PRAXO-CORE

**A public, MIT-licensed agent framework for the AxisVela ecosystem.**

PRAXO-CORE provides the reusable primitives behind PRAXOVELA and other
AxisVela agents: models, tools, memory, events, scheduling, policy, sandboxing,
checkpoints, the runtime plugin plane, and the agent loop. It is a framework,
not a product.

> **One-liner:** build governed agents without rebuilding the loop, provider
> abstraction, tool contracts, or memory/event boundaries.

## Framework, Not Product

| Layer | What it is | License |
| --- | --- | --- |
| `praxo-core` | Reusable agent framework and contracts (PRAXOVELA family) | MIT |
| PRAXOVELA | Runnable agent runtime product built on the framework | AGPL-3.0 |

The MIT boundary lets PRAXOVELA and external products embed the framework
without inheriting AGPL obligations. PRAXOVELA remains an AGPL product.

## Module

`github.com/axisvela/praxo-core/v2` (v2 semantic import path). The `v1` tags
remain available for consumers that have not migrated; see the
[v2 migration guide](docs/11-migration-v2.md).

## Primitives

- `pkg/model` - model/provider abstraction and messages.
- `pkg/tool` - tool contracts and registry; `pkg/tool/jsonschema` validates schemas.
- `pkg/toolcall` - model-output tool-call parsing and markup stripping.
- `pkg/memory` - memory and context interfaces.
- `pkg/event` - event envelopes and sinks.
- `pkg/scheduler` - schedule definitions and scheduler engine.
- `pkg/policy` - decision hooks, authorization boundary, and path containment.
- `pkg/sandbox` - execution sandbox interface.
- `pkg/checkpoint` - durable run snapshots and the resume store contract.
- `pkg/httpclient` - shared retry-capable HTTP transport for adapters.
- `pkg/formatter` - language formatter detection and execution.
- `pkg/flow` - Runnable, Chain, and Parallel composition.
- `pkg/prompt` - prompt and chat templates.
- `pkg/retriever` - document retrieval contracts.
- `pkg/vfs` - virtual filesystem backend contract, confined local backend, and filesystem tools.
- `pkg/plugin` - runtime plugin contracts, manifest v1, lifecycle, registry, hosts, and conformance kit.
- `pkg/agent` - the governed agent loop with middleware, budgets, context compaction, and subagent management. Capability packages live under `pkg/agent/{types,context,delegation,evaluation,hitl,middleware,stream}`; root aliases keep `agent.*` imports source-compatible.

## Example

```go
ag, err := agent.New(agent.Options{
    Model:    myModel,
    Tools:    tools,
    Events:   sink,
    Policy:   hook,
    MaxSteps: 8,
})
if err != nil {
    return err
}
result, err := ag.Run(ctx, agent.Session{
    ID: "session-1",
    TenantID: "acme",
    WorkspaceID: "default",
}, "Inspect the failing test and propose a fix")
```

See [examples/integrator](examples/integrator/main.go) for a self-contained external-integrator example.

## Status

`2.0.0` was released on 2026-10-18. It changes only the module path to
`github.com/axisvela/praxo-core/v2`; the exported API is functionally identical
to `1.7.0` (`api/2.0.0.txt`; the `1.7.0` diff is module-path updates only). The
`1.0.0` API freeze remains in effect, and the canonical package paths are
`pkg/toolcall`, `pkg/formatter`, and `pkg/tool/jsonschema`. The `1.x` line adds
plugin hosts, the conformance kit, Manifest v1, path containment, context budget
compaction, context summarization/offload, VFS tools, async subagents,
structured output, PII redaction, HITL decisions, typed streams, and todo
planning. The framework is extracted from PRAXOVELA's proven runtime.

## Documentation

- [Overview](docs/00-overview.md)
- [Architecture](docs/01-architecture.md)
- [Primitives](docs/02-primitives.md)
- [Integration](docs/03-integration.md)
- [License and provenance](docs/04-license-and-provenance.md)
- [Compatibility](docs/05-compatibility.md)
- [v2 migration](docs/11-migration-v2.md)
- [Security policy](SECURITY.md)
- [API freeze inventory](docs/07-api-freeze.md)
- [Security model](docs/08-security.md)
- [Release process](docs/09-release.md)
- [Plugin authoring](docs/10-plugin-authoring.md)
- [Roadmap detail](docs/06-roadmap.md)
- [Roadmap](ROADMAP.md)

Internal extraction planning and product-family sequencing live in the private
PRAXOVELA-EE repository.

## License

MIT. See [LICENSE](LICENSE).
