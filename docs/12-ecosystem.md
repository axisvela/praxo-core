# AxisVela Ecosystem Integration

PRAXO-CORE is the framework layer shared by AxisVela agents. It exposes neutral
contracts so each ecosystem component can supply an adapter without changing the
agent loop.

## Integration Map

| Ecosystem component | PRAXO-CORE seam | Typical adapter |
| --- | --- | --- |
| Models | `pkg/model` (`Model`, `Provider`, `ProviderProfile`) | PRAXOVELA provider router / consumer adapters |
| Memory | `pkg/memory` (`Store`, `ContextAssembler`) | Mnemovela |
| Events | `pkg/event` (`Sink`, `PublisherSink`) | Harmovela / Argus Trace |
| Retrieval | `pkg/retriever` (`Retriever`, `Document`) | GNOSIVELA / Mnemovela |
| Policy | `pkg/policy` (`Hook`, `PathChecker`) | AEGIVELA / Archon Guard |
| Sandbox | `pkg/sandbox` (`Sandbox`, `Interpreter`) | Vulcan Forge |
| Tools | `pkg/tool` (`Tool`, `Gateway`) | Janus Gateway |
| Graph execution | `pkg/agent`, `pkg/agent/stream` | RHEOVELA |
| Product runtime | All interfaces | PRAXOVELA |

## How the Seams Work

- **Models.** Implement `model.Model` or adapt an existing provider router.
  `model.ProviderProfile` describes context, output, tool, stream, and cache
  capabilities by model prefix.
- **Memory.** Implement `memory.Store` for conversation, workspace, or long-term
  memory. Mnemovela supplies the product-backed store.
- **Events.** Implement `event.Sink` and publish lifecycle facts to Harmovela.
  The same events can be persisted in Argus Trace.
- **Retrieval.** Implement `retriever.Retriever`; GNOSIVELA and Mnemovela can
  supply documents and context.
- **Policy.** Implement `policy.Hook` for authorization; AEGIVELA and Archon
  Guard plug in here. `policy.PathChecker` provides built-in path containment.
- **Sandbox.** Implement `sandbox.Sandbox` for isolated command execution;
  Vulcan Forge supplies the product isolation.
- **Tools.** Register `tool.Tool` values. Janus Gateway exposes product-owned
  external tools through `tool.Gateway`.
- **Graph execution.** RHEOVELA owns graph and subgraph execution. PRAXO-CORE
  exposes the agent node, session, and stream boundary.
- **Plugins.** `pkg/plugin/bridge` maps a runtime plugin host to the tool,
  model, policy, memory, and sandbox contracts.

## Boundaries

- Interfaces and wire contracts live in the MIT framework.
- Concrete adapters, credentials, tenant policy, trust stores, SBOM/evidence,
  and plugin materialization are product-owned.
- The framework does not import product code and does not bundle provider SDKs,
  vector databases, or an MCP client.
- This repository lists integration seams, not shipped adapters. Product
  implementations may live in PRAXOVELA or another AxisVela repository.
