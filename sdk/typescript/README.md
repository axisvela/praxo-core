# PRAXO-CORE TypeScript SDK

TypeScript implementation of the PRAXO-CORE contract. The normative contract is
[`spec/`](../../spec/README.md); Go remains the reference implementation.

**Status:** The package passes all eleven conformance vector groups
and the TypeScript parity check. Context budgets, middleware, streaming,
`AbortSignal` cancellation, and the OpenAI-compatible adapter are included.
`npm pack` and `npm publish --dry-run` are verified; npm publication is pending.
Use the source build below. VFS and plugin hosts are not yet implemented.

Package version: `0.1.0`. Supported contract: `SPEC_VERSION` `0.2.0`
(`SPEC_VERSION` export).

## Requirements

- Node 20 or newer
- No runtime dependencies

## Build and test

```bash
cd sdk/typescript
npm ci
npm run build
npm run conformance
node --test tests
```

## Usage

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
`plugin_id`. The checked-in API snapshot is `api/<version>.txt`; refresh it with
`npm run api` and verify it with `npm run api:check`.

## Conformance

The runner reads `../../spec/vectors/*.json`. A released SDK must pass every vector
and keep `spec/parity.md` current. `SPEC_VERSION` is exported from the package.

## License

MIT. See [LICENSE](LICENSE).
