# PRAXO-CORE Java Core

Java implementation of the PRAXO-CORE contract. The normative contract is
[`spec/`](../../spec/README.md); Go remains the reference implementation.

**Status:** The package passes all eleven conformance vector groups.
Context budgets, middleware, streaming, virtual-thread execution, cancellation,
the OpenAI-compatible, Anthropic, and Gemini adapters, Harmovela sink, stdio MCP
client, HITL interrupt decisions, and the agent loop are included. VFS and
plugin hosts are not yet implemented.

Source version: `0.9.0` (source tag `java/v0.9.0`; the earlier
`java/v0.2.3` tag retains `io.axisvela.praxo`). Maven Central publishes `0.6.0`.
Supported contract:
`SPEC_VERSION` `0.2.0` (`com.axisvela.praxo.Version.SPEC_VERSION`).

Maven Central publishes the release matching the source tag. Check Central
metadata rather than inferring availability from this README when upgrading.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/java/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/java/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/java/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.6.0/)

## Install

```xml
<dependency>
  <groupId>com.axisvela</groupId>
  <artifactId>praxo-core</artifactId>
  <version>0.5.0</version>
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
| `com.axisvela.praxo.plugin` | Manifest v1 parsing and validation |
| `com.axisvela.praxo.adapters` | OpenAI-compatible adapter and Harmovela event sink |

Wire codecs preserve the Go names, including `image_url`, `runId`, and
`plugin_id`. The Java Core uses a dependency-free JSON utility (`util/Json.java`)
with no runtime dependencies. Model and tool calls run on virtual threads with
`CancellationToken`-based cancellation.

## Conformance

The runner reads `../../spec/vectors/*.json`. A released Core implementation must pass every vector
and keep `spec/parity.md` current.

## License

MIT. See [LICENSE](LICENSE).
