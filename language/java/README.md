# PRAXO-CORE Java Core

Java implementation of the PRAXO-CORE contract. The normative contract is
[`spec/`](../../spec/README.md); Go remains the reference implementation.

**Status:** The package passes all eleven conformance vector groups.
Context budgets, middleware, streaming, virtual-thread execution, cancellation,
the OpenAI-compatible, Anthropic, and Gemini adapters, Harmovela sink, stdio MCP
client, HITL interrupt decisions, the process plugin host, and the agent loop
are included. VFS and other plugin hosts are not yet implemented.

The latest source tag is `java/v0.12.0`; the earlier `java/v0.2.3` tag retains
`io.axisvela.praxo`. Maven Central publishes `0.12.0`.
Supported contract:
`SPEC_VERSION` `0.2.0` (`com.axisvela.praxo.Version.SPEC_VERSION`).

Check Central metadata rather than inferring availability from the working-tree
source version when upgrading.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/java/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/java/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/java/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/java/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.0/)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Get started

Install the published package:

```bash
Maven: com.axisvela:praxo-core:0.12.0
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [Java documentation](https://axisvela.github.io/praxo-core/languages/java/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/java/examples`](https://github.com/axisvela/praxo-core/tree/main/language/java/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/mcp) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/identity-policy) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/service) with introspection, revocation, and OIDC/JWKS (compile-verified locally) |
| Approve or edit a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/hitl) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/session-checkpoint) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/java/examples/event-sink) |

## Install

```xml
<dependency>
  <groupId>com.axisvela</groupId>
  <artifactId>praxo-core</artifactId>
  <version>0.12.0</version>
</dependency>
```

## Requirements

- Java 21 or newer
- Maven 3.9 or newer

## Build and test

```bash
cd language/java
mvn -q -DskipTests test-compile
mvn -q -DskipTests package
java -cp target/classes com.axisvela.praxo.conformance.ApiSnapshot --check
java -cp target/classes com.axisvela.praxo.conformance.Run
java --add-modules jdk.httpserver -cp target/classes:target/test-classes com.axisvela.praxo.adapters.OpenAICompatibleSelfTest
java -cp target/classes:target/test-classes com.axisvela.praxo.adapters.HarmovelaSinkSelfTest
java -cp target/classes:target/test-classes com.axisvela.praxo.adapters.McpSelfTest
java -cp target/classes:target/test-classes com.axisvela.praxo.agent.AgentConcurrencySelfTest
```

## Usage

For a complete application with explicit tool scope, policy denial tests, and
published-artifact provenance checks, use the
[independent Java consumer](../../docs/getting-started/consumer-java.md).


```java
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.tool.FuncTool;
import com.axisvela.praxo.tool.Registry;

var tools = new Registry();
tools.register(new FuncTool("echo", "Echo", args -> args));

var agent = new Agent(new AgentOptions(request -> Response.of(
        Message.assistant("hello", java.util.List.of()))));
var result = agent.run(new Session("session-1"), "hi");
System.out.println(result.output + " " + result.steps);
```

## Harmovela event sink

`HarmovelaSink` posts lifecycle events to `{baseUrl}/events` as JSON envelopes
with `spec_version`, `id`, `type`, `source`, `created_at`, and a payload that
merges the event data with `session_id` and `run_id` when present.

```java
import com.axisvela.praxo.adapters.HarmovelaSink;

var options = new AgentOptions(model);
options.events = new HarmovelaSink("http://127.0.0.1:8790/aep/api");
var agent = new Agent(options);
```

Pass a `HarmovelaSink.Transport` to inject a fake for tests. Limits: the sink
adds no authentication, retries, buffering, acknowledgements, ordering, or
exactly-once delivery. Filter sensitive event data at the caller, and use HTTPS
for remote endpoints.

## MCP stdio client

`adapters.McpClient` spawns a child process that speaks newline-delimited
JSON-RPC 2.0 over stdio. It performs the `initialize` /
`notifications/initialized` handshake, follows `tools/list` cursors, rejects
repeated cursors and duplicate names, preserves `inputSchema`, and maps
`tools/call` structured or text content.

```java
import com.axisvela.praxo.adapters.McpClient;
import com.axisvela.praxo.adapters.McpServerConfig;
import com.axisvela.praxo.tool.Registry;

var client = McpClient.connect(
        McpServerConfig.of("my-mcp-server", "--stdio"));
var registry = new Registry();
client.registerTools(registry);
client.close();
```

`registerTools` uses the normal `Registry` and `Tool` seam, so policy and tool
authorization still apply. `McpToolAdapter.spec` and `McpTool.toSpec` preserve
the model-facing input schema. Failures use `MCP_PROTOCOL`, `MCP_TRANSPORT`,
`MCP_HANDSHAKE`, `MCP_PAGINATION`, `MCP_DUPLICATE_TOOL`, `MCP_TOOL_ERROR`,
`MCP_RPC`, `MCP_TIMEOUT`, `MCP_CLOSED`, and `MCP_CANCELLED` codes.

Limits: stdio transport only; no remote transport, authentication, sandbox
isolation, or schema promotion. Tool output is untrusted and MCP authentication
belongs to the child process. `close` terminates the child; in-flight timeouts
send `notifications/cancelled` but do not prove remote work stopped. The
included tests use a deterministic fake server, not a live service.

## Contract Surface

| Package | Contract |
| --- | --- |
| `com.axisvela.praxo.model` | Model, messages, tool specs, request/response, usage |
| `com.axisvela.praxo.tool` | Tool, Registry, FuncTool |
| `com.axisvela.praxo.event` | Event, Sink, multi/filter sinks |
| `com.axisvela.praxo.policy` | Hook, Decision, PathChecker |
| `com.axisvela.praxo.memory` | Store, MemoryRecord, MemoryStore |
| `com.axisvela.praxo.checkpoint` | Allowlist |
| `com.axisvela.praxo.context` | budgets, summarization, offload, AGENTS.md |
| `com.axisvela.praxo.middleware` | call limits, fallback, PII, structured output, tool selection |
| `com.axisvela.praxo.agent` | Agent, AgentOptions, Session, Result |
| `com.axisvela.praxo.hitl` | Interrupt, InterruptDecision, approve/edit/reject/respond handlers |
| `com.axisvela.praxo.toolcall` | tool-call parsing and markup stripping |
| `com.axisvela.praxo.jsonschema` | documented JSON Schema subset |
| `com.axisvela.praxo.plugin` | Manifest v1 parsing, validation, and process host |
| `com.axisvela.praxo.adapters` | OpenAI-compatible adapter and Harmovela event sink |

Wire codecs preserve the Go names, including `image_url`, `runId`, and
`plugin_id`. The Java Core uses a dependency-free JSON utility (`util/Json.java`)
with no runtime dependencies. Model and tool calls run on virtual threads with
`CancellationToken`-based cancellation.

## Conformance

The runner reads `../../spec/vectors/*.json`. A released Core implementation must pass every vector
and keep `spec/parity.md` current.


## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for Java.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [airport-recovery](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/airport-recovery) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [api-orchestration](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/api-orchestration) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [architecture-graph](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/architecture-graph) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [budget-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/budget-review) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [clinical-guidelines](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/clinical-guidelines) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [container-yard](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/container-yard) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [credit-diligence](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/credit-diligence) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [customs-reroute](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/customs-reroute) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [due-diligence](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/due-diligence) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [legacy-migration](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/legacy-migration) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [medical-coding](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/medical-coding) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [order-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review) | This tutorial embeds the native Java Core in a loopback HTTP application. It uses the same synthetic business service as Python and TypeScript, not a shared remote Agent. The in... |
| [patent-fto](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/patent-fto) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [precedent-outline](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/precedent-outline) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [public-approval](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/public-approval) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [rpa-reconciliation](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/rpa-reconciliation) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [supply-disruption](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/supply-disruption) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [tax-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/tax-review) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [tender-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/tender-review) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [test-generation](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/test-generation) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [trial-screening](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/trial-screening) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service) | A native Java Core tutorial for a review-only wealth workflow. The Agent has two fixed tools: `read_portfolio` reads synthetic account `acct-100`, and `draft_rebalance` produces... |
| [zero-trust-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/zero-trust-review) | A bounded tutorial slice over the native Java Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |

Index: [language/java/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for this language yet. Candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).

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


## License

MIT. See [LICENSE](LICENSE).
