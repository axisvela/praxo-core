# AxisVela Ecosystem Integration

PRAXO-CORE is the framework layer shared by AxisVela agents. It exposes neutral
contracts so ecosystem components can supply adapters without changing the agent
loop. Most AxisVela public repositories integrate in one of four ways: a core
runtime seam, a tool or gateway, an event/coordination protocol, or a
product-runtime adapter.

## Core Integration Map

| Ecosystem component | PRAXO-CORE seam | Typical adapter |
| --- | --- | --- |
| Models and inference routing | `pkg/model` (`Model`, `Provider`, `ModelRouter`, `ProviderProfile`) | [NOETIVELA](https://github.com/axisvela/noetivela-open) / PRAXOVELA provider router |
| Memory | `pkg/memory` (`Store`, `ContextAssembler`) | [Mnemovela](https://github.com/axisvela/mnemovela-open) |
| Events | `pkg/event` (`Sink`, `PublisherSink`) | [Harmovela](https://github.com/axisvela/harmovela) / Argus Trace |
| Retrieval | `pkg/retriever` (`Retriever`, `Document`) | [GNOSIVELA](https://github.com/axisvela/gnosivela-open) / Mnemovela |
| Policy | `pkg/policy` (`Hook`, `PathChecker`) | [AEGIVELA](https://github.com/axisvela/aegivela-open) / Archon Guard |
| Sandbox | `pkg/sandbox` (`Sandbox`, `Interpreter`) | Vulcan Forge |
| Tools | `pkg/tool` (`Tool`, `Gateway`) | Janus Gateway / [LIMENORA](https://github.com/axisvela/limenora-open) |
| Graph execution | `pkg/agent`, `pkg/agent/stream` | [RHEOVELA](https://github.com/axisvela/rheovela-open) |
| Product runtime | All interfaces | [PRAXOVELA](https://github.com/axisvela/praxovela-open) |

Adapter skeletons: [`examples/ecosystem`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem).

## Adapter Modules

- [`adapters/openaicompat`](https://github.com/axisvela/praxo-core/tree/main/adapters/openaicompat) is a standard-library
  OpenAI-compatible model adapter. It works with Ollama, vLLM, and hosted
  OpenAI-compatible endpoints.
- [`adapters/mcp`](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp) is an optional MCP tool gateway module.
  It is a separate Go module so the core framework does not depend on the MCP
  SDK.
- [`adapters/otel`](https://github.com/axisvela/praxo-core/tree/main/adapters/otel) is an optional OpenTelemetry event sink.
  It maps lifecycle events to spans without adding OpenTelemetry to the core
  module.
- [`adapters/anthropic`](https://github.com/axisvela/praxo-core/tree/main/adapters/anthropic) is a native Anthropic Messages
  adapter with tool calls, usage, and SSE streaming.

## NOETIVELA and Model Routing

Yes. [NOETIVELA](https://github.com/axisvela/noetivela-open) is the AxisVela
inference fabric and can back the model seam.

- Wrap the NOETIVELA governed chat API in `model.Model` or `model.Provider`;
  `model.ChatModel` adapts a `Provider` to `Model`.
- Map the neutral `model.Request` to a NOETIVELA Inference Contract inside the
  adapter. Contract fields such as task, modality, region, and data
  classification are adapter or product configuration; the core request does
  not add NOETIVELA-specific fields. The agent does not populate
  `model.Request.Model`, so derive the contract from adapter state, run context,
  or messages rather than assuming a model name.
- Use `model.ProviderProfile` when you need per-endpoint context, output, tool,
  stream, or cache capabilities.
- The framework does not vendor the NOETIVELA Go SDK or provider credentials.
  `noetivela-open` is Apache-2.0 and can be imported by the adapter or product.
- The [`examples/ecosystem-sdk`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk) module uses the
  real NOETIVELA, Mnemovela, and GNOSIVELA Go SDKs. It is a separate module so
  the core framework module stays free of product SDK dependencies.
- The `ecosystem.Noetivela` adapter skeleton shows a contract-mapping shape;
  `ecosystem.Model` and `ecosystem.Provider` cover the generic callback shape.
- The [runnable demo](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem/cmd/demo) wires the NOETIVELA,
  memory, event, policy, and tool-gateway adapters into an agent.
- The NOETIVELA SDK `ChatResponse` exposes text content, not tool calls. For
  agent tool calling, use a custom HTTP adapter that preserves tool-call fields,
  or keep tool execution in the product runtime.

## Other AxisVela Components

These components are not core agent-loop primitives, but they can integrate
through tools, events, policy inputs, or product-runtime adapters. Browse the
[current public repository list](https://github.com/orgs/axisvela/repositories?q=visibility%3Apublic+archived%3Afalse).

| Component | Public repository | Integration mode |
| --- | --- | --- |
| EIDOVELA | [eidovela-open](https://github.com/axisvela/eidovela-open) | Agent identity; product runtime or policy input |
| NOMIVELA | [NOMIVELA-open](https://github.com/axisvela/NOMIVELA-open) | Agent registry and namespace; product runtime or tool discovery |
| SYMBIVELA | [symbivela-open](https://github.com/axisvela/symbivela-open) | Human approval and intervention; HITL decisions or product UI |
| TEKMOVELA | [tekmovela-open](https://github.com/axisvela/tekmovela-open) | Verification and assurance; tools or release gates |
| MODUREGIS | [moduregis-open](https://github.com/axisvela/moduregis-open) | Capability registry; `tool.Registry` or `tool.Gateway` |
| SYNDOVELA | [SYNDOVELA-open](https://github.com/axisvela/SYNDOVELA-open) | Skill composition; tools or skills loaded by the product |
| ONTOVELA | [ontovela-open](https://github.com/axisvela/ontovela-open) | Digital twins and world models; tools or retrieval |
| ORCHADYN | [orchadyn-open](https://github.com/axisvela/orchadyn-open) | Capability planning; tools or product orchestration |
| COORDIVELA | [coordivela-open](https://github.com/axisvela/coordivela-open) | Development coordination; events, tools, or product integration |
| KINETOVELA | [kinetovela-open](https://github.com/axisvela/kinetovela-open) | Robot fleet execution; tools, sandbox, or product integration |
| PEIRAVELA | [peiravela-open](https://github.com/axisvela/peiravela-open) | Experiment control; tools or product integration |

## How the Core Seams Work

- **Models.** Implement `model.Model` or adapt an existing provider router.
  `model.ProviderProfile` describes context, output, tool, stream, and cache
  capabilities by model prefix.
- **Memory.** Implement `memory.Store` for conversation, workspace, or long-term
  memory.
- **Events.** Implement `event.Sink` and publish lifecycle facts to Harmovela.
  The same events can be persisted in Argus Trace.
- **Retrieval.** Implement `retriever.Retriever`; GNOSIVELA and Mnemovela can
  supply documents, semantic grounding, and context.
- **Policy.** Implement `policy.Hook` for authorization; AEGIVELA and Archon
  Guard plug in here. `policy.PathChecker` provides built-in path containment.
- **Sandbox.** Implement `sandbox.Sandbox` for isolated command execution;
  Vulcan Forge supplies the product isolation.
- **Tools.** Register `tool.Tool` values. Janus Gateway and LIMENORA expose
  product-owned external tools through `tool.Gateway`.
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
