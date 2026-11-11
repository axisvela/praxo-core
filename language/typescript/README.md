# PRAXO-CORE: TypeScript Agent Framework

PRAXO-CORE is a dependency-free TypeScript framework for building tool-using AI
agents. It provides the agent runtime, not a model or hosted service, so you keep
control of your models, tools, storage, and sandboxing.

It is for teams that want a small, explicit agent loop instead of a large
orchestration platform:

- Typed models, tools, events, and sessions.
- Policy hooks, approvals, path checks, PII redaction, and call limits.
- Context budgets, checkpoints, middleware, and fallback models.
- Streaming, `AbortSignal` cancellation, and an OpenAI-compatible adapter.
- No runtime dependencies; Node.js 20 or newer.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/typescript/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/typescript/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/typescript/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.3.0)

## Install

```bash
npm install @axisvela/praxo-core@0.3.0
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
| Integration | OpenAI-compatible adapter; bring your own model and tools |

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
- [Examples](https://github.com/axisvela/praxo-core/tree/main/examples)

## Contract and status

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation. This package supports `SPEC_VERSION` `0.2.0` and
passes the TypeScript conformance and parity checks. Version `0.3.0` is released
from tag `typescript/v0.3.0` and published on npm with provenance. VFS and plugin
hosts are not yet implemented.

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
| `src/adapters/openaicompat.ts` | OpenAI-compatible non-streaming and SSE adapter |
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

## License

MIT. See [LICENSE](LICENSE).
