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

## Install

```bash
npm install @axisvela/praxo-core@0.1.5
```

## Quickstart

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
| Governance | Policy hooks, tool selection, PII middleware, call limits |
| Runtime | Context budgets, checkpoints, events, streaming, cancellation |
| Integration | OpenAI-compatible adapter; bring your own model and tools |

## Documentation and examples

- [Documentation](https://axisvela.github.io/praxo-core/languages/typescript/)
- [中文文档](https://axisvela.github.io/praxo-core/zh-CN/languages/typescript/)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/examples)

## Contract and status

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation. This package supports `SPEC_VERSION` `0.2.0` and
passes the TypeScript conformance and parity checks. Package version `0.1.5`
is published on npm with provenance. VFS and plugin hosts are not yet
implemented.

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
| `src/toolcall.ts` | tool-call parsing and markup stripping |
| `src/jsonschema.ts` | documented JSON Schema subset |
| `src/plugin.ts` | Manifest v1 parsing and validation |
| `src/adapters/openaicompat.ts` | OpenAI-compatible non-streaming and SSE adapter |

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
