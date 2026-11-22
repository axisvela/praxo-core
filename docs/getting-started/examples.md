# Examples

Use examples by task first, then by language. Go reference and cross-language
examples live in the repository
[`examples/`](https://github.com/axisvela/praxo-core/tree/main/examples)
directory. Language-specific examples live under
`language/<language>/examples/` so they are included in the dedicated language
mirror repositories. For the thirteen-theme, thirty-one-language matrix, see
[Language Coverage](language-coverage.md).

## Depth and Evidence

New domain application tutorials live in `language/<language>/Tutorial/`, as a
sibling of `examples/`. Start with [Python order review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review)
or [TypeScript order support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review).
Both use the local synthetic service in
[agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services); they are
initial deterministic slices, not completed enterprise Web applications.
Existing examples and published documentation URLs remain unchanged.
The teaching backend is public MIT source and runs locally; no hosted business
endpoint is provided. The original demo repository remains private.
The [Java order review tutorial](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review)
adds a loopback HTTP entry point and a JUnit contract fixture. Its local runtime
is blocked by this workstation's JVM launcher; Linux CI compilation and
mock-backed Agent/Web tests passed at `3c2063f9` in
[run 45031868787](https://github.com/axisvela/praxo-core/actions/runs/45031868787).
The private business-service integration job was skipped in that historical run.
The current integration job uses a pinned public backend revision, without
private credentials. All three native CLI clients passed against the real local
teaching backend at `8b0593bb` in
[run 45033109188](https://github.com/axisvela/praxo-core/actions/runs/45033109188),
using published packages and deterministic models, not live providers.

The catalog uses the depth labels from the
[Language Coverage depth audit](language-coverage.md#depth-audit):

| Depth | What it means |
| --- | --- |
| Mechanism check | Isolated schema, handler, retry, or callback assertions; may not invoke Core |
| Core integration | Invokes the actual Core model, tool, policy, checkpoint, or event seam for the claimed behavior |
| Application tutorial | Documents setup, an input-to-output task, failure handling, and continuation |

A recorded run is separate from depth: it names the revision, toolchain, command,
output, and limits. A source entry is not a working path. Check the depth audit
for mechanism-only themes and the
[verification evidence](../project/verification-evidence.md) for recorded runs.

## Choose by Task

| Task | Example | Notes |
| --- | --- | --- |
| Run a real model | [Live Model Golden Path](live-model-golden-path.md) | Published package, OpenAI-compatible endpoint, one `get_time(zone)` tool |
| Connect another provider or MCP | [Provider and MCP walkthrough](../guides/provider-walkthrough.md), [MCP tutorial](../guides/mcp-tutorial.md) | Published-package adapters, local MCP clients, and transport boundaries |
| Host MCP tools | [`language/python/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/mcp), [`language/typescript/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/mcp), [`language/csharp/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/mcp), [`language/rust/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/mcp), [`language/java/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/mcp), [`language/ruby/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/mcp), [`language/php/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/mcp), [`language/elixir/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/mcp), [`language/erlang/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/mcp), [`language/lua/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/mcp), [`language/r/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/mcp), [`language/c/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/mcp), [`language/cpp/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/mcp), [`language/fortran/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/mcp), [`language/cobol/examples/mcp`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/mcp) | In-process or stdio MCP clients with deterministic tool discovery and calls |
| Add provider fallback | [`language/python/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/provider-fallback), [`language/typescript/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/provider-fallback), [`language/csharp/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/provider-fallback), [`language/rust/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/provider-fallback), [`language/ruby/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/provider-fallback), [`language/php/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/provider-fallback), [`language/c/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/provider-fallback), [`language/cpp/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/provider-fallback), [`language/fortran/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/provider-fallback), [`language/elixir/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/provider-fallback), [`language/erlang/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/provider-fallback), [`language/lua/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/provider-fallback), [`language/r/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/provider-fallback), [`language/cobol/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/provider-fallback), [`language/java/examples/provider-fallback`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/provider-fallback) | Primary model failure falls back to a second model; deterministic tests |
| Retry transient model failures | [`language/python/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/retry), [`language/typescript/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/retry), [`language/csharp/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/retry), [`language/rust/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/retry), [`language/java/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/retry), [`language/ruby/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/retry), [`language/php/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/retry), [`language/c/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/retry), [`language/cpp/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/retry), [`language/fortran/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/retry), [`language/elixir/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/retry), [`language/erlang/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/retry), [`language/lua/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/retry), [`language/r/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/retry), [`language/cobol/examples/retry`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/retry) | Bounded model middleware retries only retryable errors and preserves exhausted failures |
| Observe agent events | [`language/python/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/event-sink), [`language/typescript/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/event-sink), [`language/csharp/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/event-sink), [`language/rust/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/event-sink), [`language/java/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/event-sink), [`language/ruby/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/event-sink), [`language/php/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/event-sink), [`language/c/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/event-sink), [`language/cpp/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/event-sink), [`language/fortran/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/event-sink), [`language/elixir/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/event-sink), [`language/erlang/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/event-sink), [`language/lua/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/event-sink), [`language/r/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/event-sink), [`language/cobol/examples/event-sink`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/event-sink) | `run.started`, `tool.call`, `run.completed`, and `FilterSink` with deterministic tests |
| Stream a response | [`language/python/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/streaming), [`language/typescript/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/streaming), [`language/csharp/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/streaming), [`language/rust/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/streaming), [`language/ruby/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/streaming), [`language/php/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/streaming), [`language/c/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/streaming), [`language/cpp/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/streaming), [`language/fortran/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/streaming), [`language/elixir/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/streaming), [`language/erlang/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/streaming), [`language/lua/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/streaming), [`language/r/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/streaming), [`language/cobol/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/streaming), [`language/java/examples/streaming`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/streaming) | Delta callbacks reconstruct the final output; deterministic fake streaming models |
| Verify installation and denial | [Consumer starters](index.md) | Published package plus deterministic allow/deny checks |
| Produce validated JSON | [Structured Output tutorial](../guides/structured-output-tutorial.md) | Thirty-one language examples with deterministic schema accept/reject checks; published-package paths for Python, TypeScript, Java, C#, and Rust |
| Process a batch into validated JSON with failure and resume | [Python Structured Output Application](../guides/python-structured-output-app.md) | Application-shaped Python path with input, result, and error files; fixture and live modes |
| Validate structured output | [Language Coverage](language-coverage.md), [Structured Output tutorial](../guides/structured-output-tutorial.md) | All 31 declared languages under `language/<language>/examples/structured-output`; valid output accepted and invalid output rejected |
| Build a workspace agent | [Workspace Agent tutorial](../guides/workspace-agent-tutorial.md) | Read-only published-package Go application |
| Embed in an application | [Application Integration Checklist](../guides/application-integration-checklist.md) | Risk-tiered checklist for read-only, side-effecting, and high-risk deployments |
| Run Core behind HTTP | [Embedded HTTP service tutorial](../guides/embedded-service-tutorial.md), [Language Coverage](language-coverage.md) | Executable HTTP servers for Go, Python, TypeScript, Java, C#, and Rust; transport-neutral handler examples for every other declared language |
| Explore the Go reference | [`examples/reference`](https://github.com/axisvela/praxo-core/tree/main/examples/reference) | Go reference application |
| Add policy and approvals | [`examples/governed-workspace`](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace) | Go example of governed execution boundaries |
| Enforce identity and policy | [Identity and policy](../guides/identity-policy.md), [Language Coverage](language-coverage.md) | Trusted principal binding, model-claim rejection, and pre-effect denial for all 31 declared languages |
| Add checkpoints | [`examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/examples/checkpoint) | Go checkpoint-store example |
| Persist checkpoints | [`language/python/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/checkpoint), [`language/typescript/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/checkpoint), [`language/csharp/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/checkpoint), [`language/rust/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/checkpoint), [`language/java/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/checkpoint), [`language/ruby/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/checkpoint), [`language/php/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/checkpoint), [`language/c/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples/checkpoint), [`language/cpp/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples/checkpoint), [`language/fortran/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples/checkpoint), [`language/elixir/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/checkpoint), [`language/erlang/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/checkpoint), [`language/lua/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/checkpoint), [`language/r/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/checkpoint), [`language/cobol/examples/checkpoint`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/checkpoint) | Application-owned storage with allowlisted payloads; latest-record round trip and unregistered-type rejection |
| Add a plugin | [`examples/plugin`](https://github.com/axisvela/praxo-core/tree/main/examples/plugin) | Go process/WASM plugin host example |
| Delegate work | [`examples/multiagent`](https://github.com/axisvela/praxo-core/tree/main/examples/multiagent) | Go local delegation example |
| Run a representative chain | [`examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/examples/representative-chain), Python [`language/python/examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/representative-chain), TypeScript [`language/typescript/examples/representative-chain`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/representative-chain) | Go real-model chain plus deterministic Python/TypeScript counterparts covering MCP, final authorization, delegation, OTel/Harmovela, and denial zero effect |
| Use focused recipes | [`examples/recipes`](https://github.com/axisvela/praxo-core/tree/main/examples/recipes) | Go recipes for providers, events, retries, VFS, and related seams |
| Integrate an ecosystem component | [`examples/ecosystem`](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem) | Optional AxisVela adapter shapes |

## Prototype Paths

Pick one path and finish it before adding another integration. These groups are
guidance, not release gates.

| Group | Outcome | Start with |
| --- | --- | --- |
| Basic | Install a published package, call a tool, and deny one unsafe call | [Quickstart](quickstart.md), [Live Model Golden Path](live-model-golden-path.md), [Consumer starters](index.md) |
| Integration | Add one real boundary: MCP, provider fallback, structured output, streaming, or HTTP service | [Provider and MCP walkthrough](../guides/provider-walkthrough.md), [Structured Output tutorial](../guides/structured-output-tutorial.md), [Embedded HTTP service tutorial](../guides/embedded-service-tutorial.md) |
| Hardening | Make one integration safe to deny, approve, persist, retry, or cancel | [Identity and policy](../guides/identity-policy.md), [Application Integration Checklist](../guides/application-integration-checklist.md), [Consumer test template](../guides/consumer-test-template.md) |
| Advanced | Add plugins, delegation, long-running operations, workspace providers, or embodied seams | [Advanced examples](../guides/advanced-examples.md), [Plugin guide](../guides/plugins.md), [Multi-agent patterns](../guides/multi-agent.md), [Long-running operations](../guides/long-running-operations.md) |

Depth varies inside every group. Basic examples are Core integrations with
deterministic checks; Integration examples mix Core integrations and mechanism
checks; Hardening and Advanced examples are application-shaped Go recipes or
tutorials unless a language README says otherwise. Use the
[depth audit](language-coverage.md#depth-audit) rather than assuming equal depth
from the task label.

The primary SDKs share the same task-oriented catalog, but each language keeps
its own install command and executable example. A Go example is not evidence
that another SDK's example runs.

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
| C | [`language/c/examples`](https://github.com/axisvela/praxo-core/tree/main/language/c/examples) |
| C++ | [`language/cpp/examples`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples) |
| Fortran | [`language/fortran/examples`](https://github.com/axisvela/praxo-core/tree/main/language/fortran/examples) |
| Erlang | [`language/erlang/examples`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples) |
| R | [`language/r/examples`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples) |
| COBOL | [`language/cobol/examples`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples) |
| Elixir | [`language/elixir/examples`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples) |
| Lua | [`language/lua/examples`](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples) |

Each language example directory has its own README with installation and run
commands. Every declared language includes `consumer`, `live-model`, `hitl`,
and `session-checkpoint` entries. See [Language Coverage](language-coverage.md)
for the per-language matrix. Python, TypeScript, Java, Rust, C#, and other Core
implementations remain independently versioned; use the
[language matrix](../languages/matrix.md) for current support. The only complete
end-to-end prototype tutorial today is the Go [Workspace Agent
tutorial](../guides/workspace-agent-tutorial.md); the other primary SDKs have
task-focused examples but still need a comparable tutorial.

## How Examples Are Organized

- `examples/` contains Go reference examples and cross-language integrations.
- `language/<language>/examples/` contains language-specific runnable examples.
- Language examples are copied into the corresponding discovery mirror.
- Examples that install a published package do not require a repository checkout
  or local package replacement.

Do not treat examples as production security profiles. Identity, durable
approvals, effect reconciliation, and isolation remain application
responsibilities.
