# PRAXO-CORE

[English](README.md) | [简体中文](README.zh-CN.md)

**A public, MIT-licensed agent framework for the AxisVela ecosystem.**

PRAXO-CORE provides the reusable primitives behind PRAXOVELA and other
AxisVela agents: models, tools, memory, events, scheduling, policy, sandboxing,
checkpoints, the runtime plugin plane, and the agent loop. It is a framework,
not a product.

> **One-liner:** build governed agents without rebuilding the loop, provider
> abstraction, tool contracts, or memory/event boundaries.

**Comparison:** [PRAXO-CORE vs other Go agent frameworks](docs/comparison.md)
(LangChainGo, Eino, Google ADK Go, Microsoft Agent Framework Go).

## Framework, Not Product

| Layer | What it is | License |
| --- | --- | --- |
| `praxo-core` | Reusable agent framework and contracts (PRAXOVELA family) | MIT |
| PRAXOVELA | Runnable agent runtime product built on the framework | AGPL-3.0 |

The MIT boundary lets PRAXOVELA and external products embed the framework
without inheriting AGPL obligations. PRAXOVELA remains an AGPL product.

## AxisVela Ecosystem

PRAXO-CORE is the framework layer of the AxisVela family. It is not tied to a
single product: the same interfaces connect models, memory, events, retrieval,
policy, sandboxing, tools, and graph execution to the corresponding AxisVela
components. Concrete adapters and credentials stay with the product or
integrator.

| Ecosystem component | PRAXO-CORE seam | Typical adapter |
| --- | --- | --- |
| Models and inference routing | `pkg/model` (`Model`, `Provider`, `ModelRouter`, `ProviderProfile`) | NOETIVELA (NOETIVELA-open) / PRAXOVELA provider router |
| Memory | `pkg/memory` (`Store`, `ContextAssembler`) | Mnemovela |
| Events | `pkg/event` (`Sink`, `PublisherSink`) | Harmovela / Argus Trace |
| Retrieval | `pkg/retriever` (`Retriever`, `Document`) | GNOSIVELA / Mnemovela |
| Policy | `pkg/policy` (`Hook`, `PathChecker`) | AEGIVELA / Archon Guard |
| Sandbox | `pkg/sandbox` (`Sandbox`, `Interpreter`) | Vulcan Forge |
| Tools | `pkg/tool` (`Tool`, `Gateway`) | Janus Gateway / LIMENORA |
| Graph execution | `pkg/agent`, `pkg/agent/stream` | RHEOVELA |
| Product runtime | All interfaces | PRAXOVELA |

NOETIVELA is the AxisVela inference fabric and can back the model seam through
a `model.Model` or `model.Provider` adapter. Other AxisVela control planes
(identity, assurance, HITL, capabilities, twins, planning, coordination) plug in
through tools, events, or product-runtime adapters rather than core primitives.

Adapters are optional and product-owned; the framework never imports product
code. See [AxisVela ecosystem integration](docs/12-ecosystem.md) and the
[adapter skeletons](examples/ecosystem).

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

## How It Compares

The Go agent ecosystem has several strong frameworks. This table is a
high-level orientation based on public documentation as of October 2026;
upstream projects evolve quickly, so verify details before adopting.

| | PRAXO-CORE | LangChainGo | Eino | Google ADK Go | Microsoft Agent Framework Go |
| --- | --- | --- | --- | --- | --- |
| Primary focus | Governed, embeddable agent runtime primitives | LangChain-style composable LLM apps | LLM app framework with graph orchestration and ADK | Code-first agent toolkit, Gemini-optimized but model-agnostic | Production agents and multi-agent workflows (public preview) |
| AxisVela ecosystem | First-class seams for NOETIVELA, Mnemovela, Harmovela, GNOSIVELA, AEGIVELA, RHEOVELA, LIMENORA | Custom adapters/tools | Custom adapters/tools | Custom adapters/tools | Custom adapters/tools |
| Orchestration | Single-agent loop, middleware, subagents, `flow` Chain/Parallel | Chains, agents, tools | Graphs/workflows, ReAct `ChatModelAgent`, `DeepAgent` multi-agent | Workflow agents, graph workflows, multi-agent composition | Graph workflows: sequential, concurrent, group, routing, subworkflows |
| Providers | Provider-neutral `model.Model`; NOETIVELA/PRAXOVELA adapters | Broad built-in provider set | Extensions via `eino-ext` | Gemini first; OpenAI adapter; model-agnostic | Foundry, Azure, OpenAI, Anthropic, Gemini, Copilot |
| Tools and MCP | Tool contracts, JSON Schema, retry, gateway; Janus/LIMENORA gateway; MCP client is consumer-owned | Tools; MCP not first-class | Tools; MCP via `eino-ext` | Rich tools, MCP toolset, A2A | Tools, MCP, A2A, AG-UI |
| Memory and RAG | Interfaces and retrieval contracts; Mnemovela memory, GNOSIVELA retrieval | Memory, loaders, vector stores | Retriever and context components | Sessions, memory, artifacts | Memory, text search/RAG, vector stores |
| Governance and extension | Policy hooks, AEGIVELA policy, path containment, sandbox seam, checkpoints, HITL, process/WASM plugin plane, event sinks | Callbacks | HITL interrupt/resume, callbacks | Lifecycle plugin hooks, auth, telemetry | Checkpointing, tool approval/HITL, OpenTelemetry |
| License | MIT | MIT | Apache-2.0 | Apache-2.0 | MIT |

PRAXO-CORE is deliberately lower-level: it does not bundle provider SDKs,
vector databases, or an MCP client. It is also the only framework here with
first-class AxisVela seams; other frameworks can still integrate AxisVela
through custom adapters or tools. Choose PRAXO-CORE when you need a small,
MIT-licensed governance and runtime boundary to embed, or native access to
NOETIVELA, Mnemovela, Harmovela, GNOSIVELA, AEGIVELA, RHEOVELA, and LIMENORA.
Choose LangChainGo, Eino, or ADK when you want batteries-included integrations
and orchestration patterns. See the [full comparison](docs/comparison.md) for
positioning and "when to choose" guidance.

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

[简体中文文档](docs/zh-CN/README.md)

- [Comparison with other Go agent frameworks](docs/comparison.md)
- [AxisVela ecosystem integration](docs/12-ecosystem.md)
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
