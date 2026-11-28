# PRAXO-CORE: TypeScript Agent Framework

PRAXO-CORE is a dependency-free TypeScript framework for building tool-using AI
agents. It provides the agent runtime, not a model or hosted service, so you keep
control of your models, tools, storage, and sandboxing.

It is for teams that want a small, explicit agent loop instead of a large
orchestration platform:

- Typed models, tools, events, and sessions.
- Policy hooks, approvals, path checks, PII redaction, and call limits.
- Context budgets, checkpoints, middleware, and fallback models.
- Streaming, `AbortSignal` cancellation, and OpenAI-compatible, Anthropic, and
  Gemini adapters.
- No runtime dependencies; Node.js 20 or newer.

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for TypeScript, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

## Get started

Install the published package:

```bash
npm install @axisvela/praxo-core@0.10.1
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [TypeScript documentation](https://axisvela.github.io/praxo-core/languages/typescript/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/typescript/examples`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/mcp) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/identity-policy) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service) |
| Run behind HTTP with verified identity | [service-auth](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service-auth) |
| Approve or edit a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/hitl) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/session-checkpoint) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/event-sink) |

## Tutorials and Reference Applications

Scenario tutorials are bounded teaching slices. Reference applications are
portfolio integrations whose end-to-end acceptance remains in the roadmap.

### Scenario Tutorials

| Scenario | Tutorial |
| --- | --- |
| SE-08 API orchestration | [api-orchestration](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/api-orchestration) |
| Copyright evidence | [copyright-evidence](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/copyright-evidence) |
| Customer support | [customer-support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support) |
| Education tutoring | [education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/education-tutoring) |
| Live show | [live-show](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/live-show) |
| CS-07 Localization draft | [localization-draft](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/localization-draft) |
| OP-02 Meeting coordination | [meeting-coordination](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/meeting-coordination) |
| OG-03 Negotiation interpretation | [negotiation-interpretation](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/negotiation-interpretation) |
| Order review | [order-review](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review) |
| Phishing awareness | [phishing-awareness](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/phishing-awareness) |
| CS-05 Retail replenishment | [retail-replenishment](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/retail-replenishment) |
| Sales CRM | [sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/sales-crm) |
| Storyboard previs | [storyboard-previs](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/storyboard-previs) |
| Travel booking | [travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking) |
| SE-01 Workspace plan | [workspace-plan](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/workspace-plan) |

Index: [language/typescript/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for TypeScript yet.
Candidate goals are tracked in the
[reference application portfolio](https://github.com/axisvela/praxo-core/blob/main/docs/project/planning/roadmap.md#reference-application-portfolio).

Planning context: [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/), [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), and [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/). Chinese: [教程计划](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/), [候选场景](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/), [教程目录](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/).

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>


## Registry and Coding-Agent Entry

- Get started, prerequisites, and installation: [language documentation](https://axisvela.github.io/praxo-core/languages/typescript/)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples): runnable language-specific examples; see each README for prerequisites and verification.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial): read the scope and validation status; source is not portfolio acceptance.
- Reference applications: no language-specific accepted end-to-end application recorded; see the [tutorial catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/).
- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/typescript/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/typescript/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/typescript/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.1)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Install

```bash
npm install @axisvela/praxo-core@0.10.1
```

## Quickstart

For a complete application with explicit tool scope, policy denial tests, and
published-package provenance checks, use the
[independent TypeScript consumer](../../docs/getting-started/consumer-typescript.md).

```ts
import {
  Agent,
  FuncTool,
  Registry,
  ROLE_ASSISTANT,
} from "@axisvela/praxo-core";

class EchoModel {
  async generate() {
    return {
      message: { role: ROLE_ASSISTANT, content: "hello" },
    };
  }
}

const tools = new Registry();
tools.register(new FuncTool("echo", "Echo", (args) => args));

const agent = new Agent({ model: new EchoModel(), tools });
const result = await agent.run({ id: "session-1" }, "hi");
console.log(result.output, result.steps, result.usage);
```

## What you get

| Area | Included |
| --- | --- |
| Agent loop | Tool calls, multi-step runs, parallel tools, structured output |
| Governance | Policy hooks, tool selection, PII middleware, call limits, HITL interrupts |
| Runtime | Context budgets, checkpoints, events, streaming, cancellation |
| Integration | OpenAI-compatible (OpenAI, DeepSeek, Kimi), Anthropic, and Gemini adapters; bring your own model and tools |

## Harmovela event sink

`HarmovelaSink` posts lifecycle events to `{baseUrl}/events` as JSON envelopes
with `spec_version`, `id`, `type`, `source`, `created_at`, and a payload that
merges the event data with `session_id` and `run_id` when present.

```ts
import { HarmovelaSink } from "@axisvela/praxo-core";

const events = new HarmovelaSink({
  baseUrl: "http://127.0.0.1:8790/aep/api",
});

const agent = new Agent({ model, events });
```

Supply `transport` to run without network access. Limits: the sink adds no
authentication, retries, buffering, acknowledgements, ordering, or exactly-once
delivery. Apply caller-side filtering before emitting sensitive event data, and
use HTTPS for remote endpoints.

## MCP client adapter

`McpClient` is a native, dependency-free stdio JSON-RPC 2.0 client for MCP
servers. It performs the `initialize` / `notifications/initialized` handshake,
follows `tools/list` pagination, preserves `inputSchema`, and calls tools.

```ts
import { McpClient, registerMcpTools, Registry } from "@axisvela/praxo-core";

const client = await McpClient.connect({
  command: "my-mcp-server",
  args: ["--stdio"],
  timeoutMs: 30_000,
});

const tools = new Registry();
registerMcpTools(tools, client, await client.listTools());

const result = await client.callTool("search", { query: "praxo" });
await client.close();
```

Pass `transport` instead of `command` to inject a custom line transport.
`listTools` and `callTool` accept `{ signal, timeoutMs }`. On timeout or
`AbortSignal` cancellation the client sends `notifications/cancelled`; local
cancellation does not prove that the remote work stopped. The registry helper
only registers tools, so the normal Agent policy and authorization seam still
applies. MCP authentication belongs to the transport or server session.

Errors extend `PraxoError` with codes `MCP_PROTOCOL`, `MCP_TRANSPORT`,
`MCP_TIMEOUT`, `MCP_CANCELLED`, `MCP_TOOL_ERROR`, and `MCP_ERROR`. Limits: stdio
only, no hosted service, no sandbox isolation, no schema promotion, and tool
output remains untrusted content.

## Documentation and examples

- [Documentation](https://axisvela.github.io/praxo-core/languages/typescript/)
- [涓枃鏂囨。](https://axisvela.github.io/praxo-core/zh-CN/languages/typescript/)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples)

## Contract and status

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation. This package supports `SPEC_VERSION` `0.2.0` and
passes the TypeScript conformance and parity checks. The latest source tag is
`typescript/v0.10.1`; the published npm package is
`@axisvela/praxo-core@0.10.1`. VFS and plugin hosts are
not yet implemented.

## Requirements

- Node 20 or newer
- No runtime dependencies

## Build and test

```bash
cd language/typescript
npm ci
npm run build
npm run conformance
node --test tests
```

CI packs the package tarball, installs it into a temporary consumer project,
and runs `tests/installed-smoke.js` with `PRAXO_CONSUMER_ROOT` set. This verifies
the published file set and installed import path, not npm registry availability.

## Contract Surface

| Module | Contract |
| --- | --- |
| `src/model.ts` | `Model`, `Request`, `Response`, messages, tool specs, usage |
| `src/tool.ts` | `Tool`, `Registry`, `FuncTool`, gateway seam |
| `src/event.ts` | `Event`, `Sink`, `MultiSink`, `FilterSink` |
| `src/policy.ts` | `Hook`, `Action`, `Decision`, `PathChecker` |
| `src/memory.ts` | `Store`, `MemoryRecord`, `MemoryStore`, `ContextAssembler` |
| `src/checkpoint.ts` | `Allowlist` |
| `src/context.ts` | budgets, summarization, offload, `AGENTS.md` |
| `src/middleware/` | call limits, fallback, PII, structured output, tool selection |
| `src/agent.ts` | `Agent`, `AgentOptions`, `Session`, `Result` |
| `src/hitl.ts` | `Interrupt`, `InterruptDecision`, approve/edit/reject/respond handlers |
| `src/toolcall.ts` | tool-call parsing and markup stripping |
| `src/jsonschema.ts` | documented JSON Schema subset |
| `src/plugin.ts` | Manifest v1 parsing and validation |
| `src/adapters/openaicompat.ts` | OpenAI-compatible non-streaming and SSE adapter with provider presets |
| `src/adapters/anthropic.ts` | Native Anthropic Messages adapter |
| `src/adapters/gemini.ts` | Native Gemini generateContent adapter |
| `src/adapters/harmovela.ts` | Harmovela HTTP event sink |
| `src/adapters/mcp.ts` | Native stdio MCP client and tool registration helper |

Wire codecs preserve the Go names, including `image_url`, `runId`, and
`plugin_id`. The checked-in export-name snapshot is `api/<version>.txt`; the
source-declaration snapshot is `api/<version>.signatures.txt`. Refresh both with
`npm run api` and verify both with `npm run api:check`.

The signature snapshot records public class constructors and members, interface
fields and optionality, function and method parameters and return types, type
aliases, enum members, and exported constant types. It is a TypeScript source
declaration gate, not a binary ABI, serializer-schema, or runtime behavior
guarantee. The export-name baseline remains unchanged for the existing version;
the signature baseline was added after that release.

## Conformance

The runner reads `../../spec/vectors/*.json`. A released Core implementation must pass every vector
and keep `spec/parity.md` current. `SPEC_VERSION` is exported from the package.


## Process plugin host

`ProcessHost` speaks the framework JSON-Lines process plugin contract with
token authentication, health handshake, invocation timeout, cancellation, and
typed call errors. See `docs/guides/plugins.md`.

## License

MIT. See [LICENSE](LICENSE).
