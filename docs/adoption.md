# Adoption Guide

This guide is for teams evaluating or integrating PRAXO-CORE. It covers the
evaluation path, a minimal prototype, production checks, and common pitfalls.

## 1. Evaluate

PRAXO-CORE is a good fit when you need:

- a governed agent loop with explicit policy, sandbox, checkpoint, memory, and
  event boundaries
- provider-neutral contracts with adapters owned by your product
- an MIT-licensed framework you can embed without AGPL obligations
- first-class seams for the AxisVela ecosystem

It is not a hosted agent service, a model provider, a vector database, or a
turnkey chat UI.

## 2. Build a 30-Minute Prototype

1. Add the module:

   ```bash
   go get github.com/axisvela/praxo-core/v2@v2.0.0
   ```

2. Use the OpenAI-compatible adapter with Ollama or a hosted endpoint:

   ```go
   adapter := openaicompat.Adapter{
       BaseURL: "http://localhost:11434/v1",
       Model:   "llama3.2",
   }
   ```

3. Register one tool and create the agent:

   ```go
   tools := tool.NewRegistry()
   tools.Register(myTool{})

   ag, err := agent.New(agent.Options{
       Model:    adapter,
       Tools:    tools,
       MaxSteps: 4,
       Policy:   policy.FuncHook(allow),
       Events:   event.FuncSink(logEvent),
   })
   ```

4. Run a session:

   ```go
   result, err := ag.Run(ctx, agent.Session{
       ID:          "demo",
       TenantID:    "local",
       WorkspaceID: "default",
   }, "Inspect the workspace and summarize it.")
   ```

The [Quickstart](quickstart.md) and [Recipes](recipes.md) cover runnable
variants.

## 3. Map Your Integration

| Need | Seam | Starting point |
| --- | --- | --- |
| Model access | `pkg/model` | `adapters/openaicompat`, NOETIVELA SDK example |
| Memory | `pkg/memory` | `memory.MemoryStore`, Mnemovela SDK example |
| Retrieval | `pkg/retriever` | GNOSIVELA SDK example |
| Tools | `pkg/tool` | `tool.Registry`, `tool.Gateway`, MCP adapter |
| Events | `pkg/event` | `event.Sink`, Harmovela publisher |
| Authorization | `pkg/policy` | `policy.Hook`, AEGIVELA |
| Execution | `pkg/sandbox` | `sandbox.Sandbox`, Vulcan Forge |
| Files | `pkg/vfs` | `localfs`, `vfstools` |
| Durability | `pkg/checkpoint` | product-owned checkpoint store |

## 4. Production Checklist

- Keep provider credentials, tenant policy, and trust roots outside the
  framework.
- Make policy fail closed and test a denial path.
- Put shell or network execution behind a sandbox.
- Persist checkpoints for long-running or side-effecting runs.
- Forward events to your observability pipeline.
- Verify plugin signatures, SBOMs, and trust before starting a host.
- Pin the framework version and run the compatibility checks in
  [Compatibility](05-compatibility.md).
- Run `GOWORK=off go test -race ./...` in CI.
- Track the [benchmarks](benchmarks.md) for regressions.

## 5. Migration Notes

- From LangChainGo, Eino, or ADK: map concepts rather than copying code. PRAXO-
  CORE keeps the loop, provider abstraction, tools, memory, events, policy, and
  plugins as separate contracts.
- v1 consumers should follow the [v2 migration guide](11-migration-v2.md).
- If you need AxisVela integration, start with the
  [ecosystem guide](12-ecosystem.md) instead of adding product-specific code to
  a general-purpose framework.

## 6. Common Pitfalls

- **`model.Request.Model` is empty.** The agent does not set it. Derive provider
  or contract configuration from adapter state, run context, or messages.
- **NOETIVELA SDK is text-only.** Its `ChatResponse` does not expose tool calls.
  Use a custom HTTP adapter for tool calling.
- **MCP auth is session-level.** `tool.Gateway.Execute`'s token argument is
  ignored by the MCP adapter.
- **MCP tool lists are cached.** Call `Refresh` after the server changes tools.
- **GNOSIVELA has no `v3` semver tag yet.** The example pins a pseudo-version.
- **VFS containment is check-then-use.** Add OS-level confinement for high-risk
  workloads.

## 7. Where to Go Next

- [Quickstart](quickstart.md)
- [Recipes](recipes.md)
- [AxisVela ecosystem](12-ecosystem.md)
- [Comparison](comparison.md)
- [Security model](08-security.md)
- [Reference workspace agent](https://github.com/axisvela/praxo-core/tree/main/examples/reference)
