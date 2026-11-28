# When Not to Use PRAXO-CORE

This page exists so teams can rule PRAXO-CORE out early. It is not a claim that
other frameworks are worse, and it does not replace the
[comparison](../project/evaluation/comparison.md) or the
[verification evidence](../project/evaluation/verification-evidence.md).

PRAXO-CORE is an embeddable, MIT-licensed execution kernel with explicit policy,
tool, checkpoint, event, memory, and sandbox seams. It is still deliberately not
a complete agent platform.

## Current Scope

The framework is broader than the first Go-only kernel:

- more than thirty Core entries, plus bridges and samples, share the contract;
- native OpenAI-compatible, Anthropic, and Gemini adapters exist across multiple
  Cores, with optional MCP, A2A, OpenTelemetry, and Harmovela integrations;
- the Go reference includes checkpoints, HITL, subagent delegation, workspace
  sessions, and process/WASM plugin hosts;
- governed and embodied profiles have acceptance designs and scoped evidence,
  but are not certified production profiles.

These capabilities reduce integration work. They do not make Core a hosted
runtime, a connector catalog, or a service owner. The exclusions below describe
platform ownership, not missing interfaces.

## It Is Not a Fit If You Need

- a hosted agent service or managed runtime;
- a visual builder or low-code agent UI;
- a graph/workflow engine with durable subgraphs, handoff, or shared graph state;
- a model provider, routing service, or inference host;
- a vector database, document platform, or complete memory product;
- a sandbox control plane with warm pools, image catalogs, networking, quotas,
  and billing;
- a managed identity provider, policy decision service, approval service, or
  effect ledger;
- a guarantee of exactly-once business effects or cross-service transactions;
- a framework built around a large catalog of providers, document loaders, and
  RAG connectors.

The framework supplies seams and optional adapters for several of these
concerns. It does not own the services or authority behind them.

## Choose Another Direction First

| If your primary need is | Start with | Why |
| --- | --- | --- |
| Graph or subgraph orchestration with durable state | Eino, LangGraph-style runtimes, or RHEOVELA | Core keeps a single-agent execution kernel with async subagents; graph, handoff, shared state, and durable graph recovery remain external |
| A large built-in catalog of providers, loaders, and vector stores | LangChainGo or another integration-heavy framework | Core ships native OpenAI-compatible, Anthropic, and Gemini adapters plus optional MCP/A2A/OTel/Harmovela seams, not a broad connector and RAG catalog |
| A managed runtime with sessions, tracing, and hosted deployment | Google ADK, Microsoft Agent Framework, or OpenAI Agents SDK | Those products cover more of the application runtime |
| Isolated code execution as the main requirement | A dedicated sandbox or workspace provider | `sandbox.Sandbox` is a seam, not an isolation product |
| Long-term memory, conflict resolution, and forget/audit policy | A dedicated memory system | `pkg/memory` is an interface, not a complete memory product |
| A non-Go stack where you will not maintain provider or tool adapters | A supported language Core or the bridge | Many Cores are available, but declared scope, parity, and adapter coverage differ; check the matrix first |
| Independent security certification or audited production deployment | A system with third-party review and deployment evidence | Core has containment, identity, and governance evidence, not a security certification |
| Per-record remote model calls in a batch with a hard deadline | Deterministic batch processing and a separate exception review that the batch does not wait on | Synchronous callbacks expose the batch window to provider latency and outages |

## What You Must Build

The in-tree adapters and examples reduce plumbing. The following remain product
responsibilities because they require credentials, durable services, or
operational authority:

| Capability | Your responsibility |
| --- | --- |
| Model access | Adapter selection, credentials, routing, retries, cost policy |
| Tools | Tool implementations, schemas, authorization, error mapping |
| Memory | Store, write policy, retrieval, conflict handling, retention, deletion |
| Retrieval | Index, embedding pipeline, grounding, freshness |
| Events and telemetry | Sink selection, persistence, sampling, retention, alerting |
| Policy and identity | Trusted identity, policy decision point, obligations, audit |
| Approvals | Durable approval store, binding to final arguments, expiry, revocation |
| Recovery | Checkpoint store, leases/fencing, effect ledger, reconciliation |
| Sandboxing | Provider selection, isolation verification, network and resource limits |
| Operations | Tenancy, quotas, billing, deployment, SLOs, incident response |

If that list is too large for the problem you are solving, a higher-level
framework or managed product may be the better choice.

## Migration and Exit Costs

Adopting PRAXO-CORE does not lock every layer equally:

- **Public Go API:** exported `pkg/...` declarations follow the
  [compatibility policy](../project/status/compatibility-policy.md) and API snapshots.
  These are the most stable part.
- **Adapters, examples, and product wiring:** concrete adapters and examples are
  not covered by the same freeze. Replacing a provider or sandbox may require
  adapter work, even when an in-tree adapter is available.
- **Language implementations:** Python, TypeScript, Java, Rust, C#, and other
  Cores share a contract, not every Go feature. Native adapters and bridges
  reduce work, but check the
  [language matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)
  and parity inventory before assuming a drop-in migration.
- **Checkpoint data:** `pkg/checkpoint` defines a Go struct with JSON fields.
  Treat persisted checkpoint data as an integration format to review and migrate,
  not as a permanently frozen cross-vendor schema.
- **Events:** `pkg/event` defines an envelope and sinks. Your event schema,
  retention, and consumers remain product-owned.
- **Security controls:** policy, approval, sandbox, and identity integrations are
  yours to operate and verify. Moving away means replacing those controls, not
  just the agent loop.

A practical exit estimate should include: adapter count, persisted checkpoint and
event compatibility, policy/approval replacement, credential and tenant
migration, and the tests needed to prove equivalent behavior.

## Decision Checklist

Answer these before adopting:

- Do we need a graph runtime or durable workflow? If yes, PRAXO-CORE alone is not
  enough.
- Do we need a managed runtime or a broad connector catalog more than a small
  governed core?
- Who owns identity, policy decisions, approvals, and the effect ledger?
- Which language Core will we use, and which features are partial or planned?
- Where will checkpoints, events, and audit data live, and who can delete them?
- Do we have a sandbox provider, and what isolation does it actually provide?
- Can we run the denial, cancellation, recovery, and containment tests we claim?
- What is the cost to remove PRAXO-CORE if the decision changes?

## If It Is Still a Fit

Use the [adoption guide](adoption.md), run the [quickstart](quickstart.md), and
review the [security model](../security/index.md). For cross-language contract
evidence, see the [compatibility lab](../languages/compatibility-lab.md).
