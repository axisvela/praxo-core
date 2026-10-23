# PRAXO-CORE Roadmap

**Current:** `2.1.0` adoption surface (2026-10-22)

**Target:** `2.2.0` provider and protocol depth

## Release History

| Version | Focus |
| --- | --- |
| 0.1.0 | model, tool, memory, event, scheduler, policy, sandbox, agent loop |
| 0.2.0 | scheduler, output, schema, flow, prompt, retriever |
| 0.3.0 | provider, tool, memory, event, policy, and sandbox adapters; formatter registry |
| 0.4.0 | agent lifecycle status |
| 0.5.0 | checkpoint contracts |
| 0.6.0 | streaming and retry |
| 0.7.0 | parallel tools and panic-safe invocation |
| 0.8.0 | tool choice, allowlists, token budget, recall |
| 0.9.0 | `agent.New(Options)` and system prompt |
| 0.10.0 | skills, response format, interrupts, run context, session store |
| 0.11.0 | profiles and model middleware |
| 0.12.0 | agent middleware stack |
| 0.13.0 | shared HTTP client |
| 0.14.0 | plugin contract layer |
| 0.15.0 | plugin hosts, Manifest v1, TCK, path containment, context budget |
| 0.16.0 | canonical `toolcall`/`formatter`/`jsonschema` paths with deprecated aliases |
| 1.0.0 | API freeze, plugin hosts, TCK, security and release gates |
| 1.1.0 | model summarization, tool-result offload, AGENTS.md memory, prompt-cache hook |
| 1.2.0 | virtual filesystem backend/tools and async/fork subagent manager |
| 1.3.0 | provider profiles, rubric evaluation, interpreter seam |
| 1.4.0 | structured output, tool selection, PII, fallback, tool retry, call limits |
| 1.5.0 | approve/edit/reject/respond HITL decisions |
| 1.6.0 | capability package split, typed streams, session resume, checkpoint allowlist |
| 1.7.0 | context editing and todo/planning middleware |
| 2.0.0 | v2 module path; API functionally identical to 1.7.0 |
| 2.1.0 | adoption surface: adapters, docs site, recipes, benchmarks, reference app |

See `CHANGELOG.md` for exact changes.

## Adoption Workstream

The next release focuses on making the framework easy to discover, try, and
integrate without changing the frozen `pkg/...` API.

- **Try:** one-command quickstart, reference workspace agent, public docs site.
- **Integrate:** OpenAI-compatible and MCP adapters; NOETIVELA, Mnemovela, and
  GNOSIVELA SDK recipes; AxisVela ecosystem map.
- **Prove:** agent-loop benchmarks, security model, compatibility gates.
- **Community:** contributing guide, issue/PR templates, Discussions, good first
  issues.
- **Release:** monthly minor cadence; separate tags for optional modules such as
  `adapters/mcp/v0.1.0`.

## 0.1.0 - Contract Baseline

Delivered:

- model, tool, memory, event, scheduler, policy, and sandbox interfaces
- governed agent loop
- echo example
- license and provenance rules

## 0.2.0 - Framework Primitives (released 2026-10-18)

Delivered:

- [x] Extract the scheduler engine from PRAXOVELA and migrate PRAXOVELA to the
  framework scheduler.
- [x] Extract tool-call parsing and JSON Schema validation from PRAXOVELA.
- [x] Add Runnable/Chain/Parallel composition.
- [x] Add prompt templates.
- [x] Add retriever contracts.
- [x] Unambiguous 0.x module path (`github.com/axisvela/praxo-core`).

Exit gate:

- no breaking interface change without a minor bump
- every primitive has a conformance test
- PRAXOVELA can consume the module through a clean dependency boundary

## 0.3.0 - PRAXOVELA Adapters (released 2026-10-18)

- [x] Tool specs, middleware, and ordered wrapping.
- [x] Event fan-out and filter sinks.
- [x] In-memory memory store and context assembler.
- [x] Provider/model adapter bridge (`ChatModel`).
- [x] Tool registry bridge (`Gateway`).
- [x] Memory adapter bridge (`RemoteStore`/`Backend`).
- [x] Event sink bridge (`PublisherSink`).
- [x] Policy hook adapter (`FuncHook`).
- [x] Sandbox adapter (`FuncSandbox`).
- [x] Context assembly and memory retrieval helpers.
- [x] Streaming model responses.
- [x] Tool middleware.
- [x] PRAXOVELA compatibility notes.
- PRAXOVELA product wiring for the bridges.

Exit gate:

- PRAXOVELA can build against PRAXO-CORE without importing internal packages.
- Adapter compatibility tests pass.

## 0.5.0 - Durable Scheduling and Recovery

- Durable schedule contract.
- Lease/fencing helpers.
- Run checkpoint and resume hooks.
- Idempotency keys for tool calls and events.
- Failure and retry semantics.

Exit gate:

- restart recovery test
- duplicate-firing prevention test
- policy-denial fail-closed test

## 1.0.0 - Stable Framework

- API stability commitment and exported API freeze inventory.
- Production-grade documentation and external integrator examples.
- Security review and threat model.
- Release gate, SBOM, and checksums.
- No competitive harness-parity expansion; the items below are post-1.0.

## 1.1.0 - Context Management Parity (released 2026-10-18)

- `ContextCompactor` interface with model-based summarization and large-result
  offload.
- Always-loaded `AGENTS.md` memory loader.
- Prompt-cache hooks for Anthropic/Bedrock-compatible providers.

Exit gate:

- a long-run test exceeds one context window without silent context loss
- compaction and offload are observable and bounded

## 1.2.0 - Delegation and Execution Parity (released 2026-10-18)

- Async subagent lifecycle: launch, check, update, cancel.
- Explicit forked subagent context mode.
- Virtual filesystem backend protocol (state, store, filesystem, composite).
- Dedicated `delete`, `glob`, and `grep` tool surface.

Exit gate:

- async subagent and virtual-filesystem backend conformance tests
- subagent cancellation and fork-context tests

## 1.3.0 - Harness Profiles and Evaluation (released 2026-10-18)

- Provider/harness profiles for tool-call quirks, context windows, and caching.
- Rubric/evaluation middleware.
- Optional in-process JavaScript interpreter.

Exit gate:

- provider-profile conformance tests
- rubric and interpreter tests

## 1.4.0 - Agent Middleware Parity (released 2026-10-18)

- Structured-output strategies (tool/provider/auto) with validation and repair.
- LLM-based tool selection and provider tool-search hooks.
- PII detection/redaction middleware.
- Model fallback, tool retry, and per-model/tool call-limit middleware.

Exit gate:

- structured-output validation/repair tests
- tool-selection and redaction tests
- fallback/call-limit conformance tests

## 1.5.0 - HITL Decisions (released 2026-10-18)

- HITL decisions: approve, edit, reject, respond.
- Product/Janus-owned follow-ups: session-aware shell tool, execution policies
  (host/sandbox/container), MCP elicitation (forms/URLs), and tool artifacts.

Exit gate:

- HITL decision-matrix tests
- product conformance for shell, execution policies, and MCP elicitation is
  tracked by PRAXOVELA/Janus, not duplicated in the core

## 1.6.0 - Runtime Interoperability (released 2026-10-18)

- [x] Typed stream projections (values/updates/messages/checkpoint/tasks/debug).
- [x] Session-level resume via `Session.Messages`; durable checkpoint storage is product-owned.
- [x] Serialization allowlist for persisted payloads (`checkpoint.Allowlist`).
- [ ] RHEOVELA integration seam (PRAXOVELA/adapters-owned): agent node/session adapter so RHEOVELA owns graph,
  subgraph, routing, and long-running workflow semantics.
- [ ] Remote execution seam for RHEOVELA workers (PRAXOVELA-owned).

Exit gate:

- stream-projection conformance tests
- agent-session interrupt/resume tests
- RHEOVELA adapter contract tests

## 1.7.0 - Context Editing and Planning (released 2026-10-18)

- [x] Declarative context editing for old tool results.
- [x] `write_todos` planning tool and todo prompt middleware.

Exit gate:

- context-edit pairing tests
- todo tool and prompt tests

## 2.0.0 - v2 Module Path (released 2026-10-18)

- [x] Move the module to `github.com/axisvela/praxo-core/v2`.
- [x] Keep the exported API functionally identical to `1.7.0`.
- [x] Keep v1 tags available for consumers that have not migrated.

Exit gate:

- v2 API snapshot and migration guide
- no functional API change from `1.7.0`

## 2.1.0 - Adoption Surface (released 2026-10-22)

- [x] Standard-library OpenAI-compatible adapter with tool calls and SSE
  streaming.
- [x] Optional MCP tool gateway module.
- [x] Quickstart, reference workspace agent, and ecosystem adapter skeletons.
- [x] Real NOETIVELA, Mnemovela, and GNOSIVELA SDK recipes.
- [x] Bilingual docs site, adoption guide, recipes, and benchmarks.
- [x] Release `v2.1.0`.
- [x] Tag `adapters/mcp/v0.1.0`.
- [ ] Publish the launch announcement and collect first external feedback.

Exit gate:

- quickstart works against Ollama and a hosted OpenAI-compatible endpoint
- docs site and recipes deployed
- benchmark and security checks green
- no `pkg/...` API change

## 2.2.0 - Provider and Protocol Depth (candidate)

- [x] Native Anthropic and Gemini adapters.
- [x] Tag `adapters/gemini/v0.1.0`.
- [x] MCP resources and prompts; streaming progress remains a candidate.
- [x] Tag `adapters/mcp/v0.2.0`.
- [x] OpenTelemetry event sink and trace correlation.
- [x] Tag `adapters/otel/v0.2.0` (v0.1.0 remains published).
- [x] Tag `adapters/anthropic/v0.1.0`.
- [x] AEGIVELA policy, LIMENORA tool-gateway, and RHEOVELA workflow recipes.
- [x] `adapters/harmovela` HTTP event adapter.
- [x] Tag `adapters/harmovela/v0.1.0`.
- [x] `adapters/a2a` A2A server adapter.
- [x] Tag `adapters/a2a/v0.1.0`.
- Production case study and published benchmark methodology.

## 2.3.0 - Ecosystem Depth (candidate)

- [x] Checkpoint and resume example.
- [x] Sandbox and policy example for high-risk tools.
- [x] Minimal process plugin and WASM host examples.
- [x] Public adapter index.

## Graph Runtime Boundary

`StateGraph`, channels, `Send`/`Command`, subgraphs, `RemoteGraph`, and
graph-level interrupt semantics are owned by RHEOVELA. PRAXO-CORE exposes only
the agent node/session/stream contract and must not grow a competing graph
runtime. LangGraph runtime parity is therefore an integration concern, not a
core feature target.

## Non-Goals

- PRAXOVELA product assembly
- model hosting
- memory storage
- workflow engine
- verification authority
- coordination control plane

## Consumers

| Consumer | Integration |
| --- | --- |
| PRAXOVELA | embeds the framework; remains AGPL |
| RHEOVELA | owns graph/subgraph execution; consumes the PRAXO-CORE agent node/session contract |
| external products | direct interface implementation |
