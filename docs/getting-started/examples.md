# Examples

Use examples by task first, then by language. Go reference and cross-language
examples live in the repository
[`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples)
directory. Language-specific examples live under
`language/<language>/examples/` so they are included in the dedicated language
mirror repositories.

## Choose by Task

| Task | Example | Notes |
| --- | --- | --- |
| Run a real model | [Live Model Golden Path](live-model-golden-path.md) | Published package, OpenAI-compatible endpoint, one `get_time` tool |
| Connect another provider or MCP | [Provider and MCP walkthrough](../guides/provider-walkthrough.md), [MCP tutorial](../guides/mcp-tutorial.md) | Published-package adapters, local MCP clients, and transport boundaries |
| Host MCP tools | [`language/python/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/mcp), [`language/typescript/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/mcp), [`language/csharp/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/mcp), [`language/rust/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/mcp) | In-process or stdio MCP clients with deterministic tool discovery and calls |
| Add provider fallback | [`language/python/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/provider-fallback), [`language/typescript/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/provider-fallback), [`language/csharp/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/provider-fallback), [`language/rust/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/provider-fallback) | Primary model failure falls back to a second model; deterministic tests |
| Retry transient model failures | [`language/python/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/retry), [`language/typescript/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/retry), [`language/csharp/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/retry), [`language/rust/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/retry) | Bounded model middleware retries only retryable errors and preserves exhausted failures |
| Observe agent events | [`language/python/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/event-sink), [`language/typescript/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/event-sink), [`language/csharp/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/event-sink), [`language/rust/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/event-sink) | `run.started`, `tool.call`, `run.completed`, and `FilterSink` with deterministic tests |
| Stream a response | [`language/python/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/streaming), [`language/typescript/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/streaming), [`language/csharp/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/streaming), [`language/rust/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/streaming) | Delta callbacks reconstruct the final output; deterministic fake streaming models |
| Verify installation and denial | [Consumer starters](index.md) | Published package plus deterministic allow/deny checks |
| Produce validated JSON | [Structured Output tutorial](../guides/structured-output-tutorial.md) | Python, TypeScript, Java, C#, and Rust `StructuredOutput` with deterministic fake-model tests |
| Build a workspace agent | [Workspace Agent tutorial](../guides/workspace-agent-tutorial.md) | Read-only published-package Go application |
| Embed in an application | [Application Integration Checklist](../guides/application-integration-checklist.md) | Risk-tiered checklist for read-only, side-effecting, and high-risk deployments |
| Run Core behind HTTP | [Embedded HTTP service tutorial](../guides/embedded-service-tutorial.md), [`examples/embedded-service-auth`](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth), [`language/python/examples/service`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service), [`language/typescript/examples/service`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service), [`language/csharp/examples/service`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/service), [`language/rust/examples/service`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/service) | Go/Python/TypeScript/C#/Rust services plus an HMAC token and tenant-policy variant |
| Explore the Go reference | [`examples/reference`](https://github.com/axisvela/praxo-core/tree/main/examples/reference) | Go reference application |
| Add policy and approvals | [`examples/governed-workspace`](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace) | Go example of governed execution boundaries |
| Enforce identity and policy | [`language/python/examples/identity-policy`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/identity-policy), [`language/typescript/examples/identity-policy`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/identity-policy), [`language/csharp/examples/identity-policy`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/identity-policy), [`language/rust/examples/identity-policy`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/identity-policy) | Trusted principal binding, model-claim rejection, and pre-effect denial |
| Add checkpoints | [`examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/examples/checkpoint) | Go checkpoint-store example |
| Persist checkpoints | [`language/python/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/checkpoint), [`language/typescript/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/checkpoint), [`language/csharp/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/checkpoint), [`language/rust/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/checkpoint) | Application-owned storage with allowlisted payloads; latest-record round trip and unregistered-type rejection |
| Add a plugin | [`examples/plugin`](https://github.com/axisvela/praxo-core/tree/main/examples/plugin) | Go process/WASM plugin host example |
| Delegate work | [`examples/multiagent`](https://github.com/axisvela/praxo-core/tree/main/examples/multiagent) | Go local delegation example |
| Use focused recipes | [`examples/recipes`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes) | Go recipes for providers, events, retries, VFS, and related seams |
| Integrate an ecosystem component | [`examples/ecosystem`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem) | Optional AxisVela adapter shapes |

## Examples vs Recipes

- [`examples/recipes`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes)
  contains Go-focused copy-paste recipes and scoped test evidence.
- `examples/` contains runnable projects, including published-package and
  language-specific integrations.

Topics such as structured output, checkpoint stores, identity, VFS containment,
and long-running operations appear in both forms. Use the recipe for the
mechanism and the example for an application-shaped integration; do not copy
both into one project.

## By Language

| Language | Examples |
| --- | --- |
| Go | [`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples) |
| Python | [`language/python/examples`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples) |
| TypeScript | [`language/typescript/examples`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples) |
| Java | [`language/java/examples`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples) |
| C# | [`language/csharp/examples`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples) |
| Rust | [`language/rust/examples`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples) |
| Ruby | [`language/ruby/examples`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples) |
| PHP | [`language/php/examples`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples) |
| Elixir | [`language/elixir/examples`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples) |
| Lua | [`language/lua/examples`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples) |

Each language example directory has its own README with installation and run
commands. Python, TypeScript, Java, Rust, C#, and other Core implementations
remain independently versioned; use the
[language matrix](../languages/matrix.md) for current support.

## How Examples Are Organized

- `examples/` contains Go reference examples and cross-language integrations.
- `language/<language>/examples/` contains language-specific runnable examples.
- Language examples are copied into the corresponding discovery mirror.
- Examples that install a published package do not require a repository checkout
  or local package replacement.

Do not treat examples as production security profiles. Identity, durable
approvals, effect reconciliation, and isolation remain application
responsibilities.
