# PRAXO-CORE vs Other Go Agent Frameworks

This page compares PRAXO-CORE with several widely used Go agent frameworks.
It is a high-level orientation, not a benchmark. The comparison also covers
fit with the AxisVela ecosystem, since PRAXO-CORE is the framework layer for
that family. It is based on public documentation as of October 2026; upstream
projects evolve quickly, so verify details before adopting.

| | PRAXO-CORE | LangChainGo | Eino | Google ADK Go | Microsoft Agent Framework Go |
| --- | --- | --- | --- | --- | --- |
| Primary focus | Governed, embeddable agent runtime primitives | LangChain-style composable LLM apps | LLM app framework with graph orchestration and ADK | Code-first agent toolkit, Gemini-optimized but model-agnostic | Production agents and multi-agent workflows (public preview) |
| AxisVela ecosystem | First-class seams for NOETIVELA, Mnemovela, Harmovela, GNOSIVELA, AEGIVELA, RHEOVELA, LIMENORA | Custom adapters/tools; no AxisVela-specific seams | Custom adapters/tools; no AxisVela-specific seams | Custom adapters/tools; no AxisVela-specific seams | Custom adapters/tools; no AxisVela-specific seams |
| Orchestration | Single-agent loop, middleware, subagents, `flow` Chain/Parallel | Chains, agents, tools | Graphs/workflows, ReAct `ChatModelAgent`, `DeepAgent` multi-agent | Workflow agents, graph workflows, multi-agent composition | Graph workflows: sequential, concurrent, group, routing, subworkflows |
| Multi-agent | Async subagent delegation (`isolated`/`fork`); no built-in graph, handoff, or agent registry | Multi-agent via agent/chain composition | `DeepAgent` multi-agent patterns | Multi-agent composition and workflow agents | Graph-based multi-agent workflows |
| Providers | Provider-neutral `model.Model`; NOETIVELA/PRAXOVELA adapters | Broad built-in provider set | Extensions via `eino-ext` | Gemini first; OpenAI adapter; model-agnostic | Foundry, Azure, OpenAI, Anthropic, Gemini, Copilot |
| Tools and MCP | Tool contracts, JSON Schema, retry, gateway; Janus/LIMENORA gateway; MCP client is consumer-owned | Tools; MCP not first-class | Tools; MCP via `eino-ext` | Rich tools, MCP toolset, A2A | Tools, MCP, A2A, AG-UI |
| Memory and RAG | Interfaces and retrieval contracts; Mnemovela memory, GNOSIVELA retrieval | Memory, loaders, vector stores | Retriever and context components | Sessions, memory, artifacts | Memory, text search/RAG, vector stores |
| Governance and extension | Policy hooks, AEGIVELA policy, path containment, sandbox seam, checkpoints, HITL, process/WASM plugin plane, event sinks | Callbacks | HITL interrupt/resume, callbacks | Lifecycle plugin hooks, auth, telemetry | Checkpointing, tool approval/HITL, OpenTelemetry |
| License | MIT | MIT | Apache-2.0 | Apache-2.0 | MIT |

## AxisVela Ecosystem Fit

PRAXO-CORE is the only framework in this table designed as the AxisVela
framework layer. It exposes seams for:

- NOETIVELA for governed model routing and inference
- Mnemovela for memory
- Harmovela for events and coordination
- GNOSIVELA for semantic retrieval and grounding
- AEGIVELA for authorization
- RHEOVELA for graph and workflow execution
- LIMENORA for external tools, APIs, and MCP gateways

These are contracts, not bundled adapters; products supply the concrete
clients. Other frameworks can integrate with AxisVela through custom adapters,
tools, HTTP, or MCP, but those integrations are not part of their core
contracts. See [AxisVela ecosystem integration](12-ecosystem.md).

## Positioning

- **PRAXO-CORE** is deliberately lower-level. It does not bundle provider SDKs,
  vector databases, or an MCP client. Its value is a small, MIT-licensed
  governance and runtime boundary that products can embed, with first-class
  seams for the AxisVela ecosystem.
- **LangChainGo** is the broadest LangChain-style port in Go, with a large set of
  providers, chains, memory backends, document loaders, and vector stores.
- **Eino** combines graph/workflow composition with an ADK, ReAct agents, and
  multi-agent patterns. Provider and tool integrations are largely delivered
  through `eino-ext`.
- **Google ADK Go** is a code-first toolkit optimized for Gemini but usable with
  other models. It includes workflow agents, graph workflows, sessions, memory,
  artifacts, MCP tools, and A2A.
- **Microsoft Agent Framework Go** targets production agents and graph-based
  multi-agent workflows, with checkpointing, HITL, OpenTelemetry, MCP, and A2A.
  The Go implementation is in public preview.

PRAXO-CORE is single-agent at the loop level but supports asynchronous subagent
delegation. The optional `adapters/multiagent` module adds bounded in-process
supervisor and sequential composition. It does not provide dynamic handoff,
shared-state, graph orchestration, or durable recovery; those belong to RHEOVELA
or the product runtime. See
[Multi-agent patterns](13-multi-agent.md).

## When to Choose PRAXO-CORE

Choose PRAXO-CORE when you need:

- native seams for the AxisVela ecosystem: NOETIVELA, Mnemovela, Harmovela,
  GNOSIVELA, AEGIVELA, RHEOVELA, or LIMENORA
- a stable, small runtime boundary to embed in a product
- provider-neutral contracts with product-owned adapters
- policy, path containment, sandbox seams, checkpoints, and HITL in the core
- a process/WASM plugin plane with a conformance kit
- an MIT-licensed framework with no AGPL imports

## When to Choose Another Framework

- Choose **LangChainGo** for a familiar LangChain-style API and broad built-in
  integrations, especially for RAG-heavy applications.
- Choose **Eino** for graph/workflow orchestration and a mature multi-agent ADK.
- Choose **Google ADK Go** for a Gemini-first, cloud-native agent toolkit with
  strong deployment and multi-agent support.
- Choose **Microsoft Agent Framework Go** when you want graph workflows and
  checkpointing inside the Microsoft/Foundry ecosystem.

If you need deep AxisVela integration, start with PRAXO-CORE rather than adding
product-specific adapters to a general-purpose framework.

## Notes

This comparison does not score performance, stability, or ecosystem maturity.
Feature descriptions follow each project's public documentation and may lag
behind the latest releases. Open an issue if a comparison point is outdated.
