# PRAXO-CORE Java SDK

Java implementation of the PRAXO-CORE contract. The normative contract is
[`spec/`](../spec/README.md); Go remains the reference implementation.

**Status:** M3 core. The package passes all eleven conformance vector groups.
Context budgets, middleware, streaming, virtual-thread execution, cancellation,
the OpenAI-compatible adapter, and the agent loop are included. VFS and plugin
hosts are not yet implemented.

Package version: `0.2.0`. Supported contract: `SPEC_VERSION` `0.2.0`
(`io.axisvela.praxo.Version.SPEC_VERSION`).

## Requirements

- Java 21 or newer
- Maven 3.9 or newer

## Build and test

```bash
cd java
mvn -q -DskipTests test-compile
mvn -q -DskipTests package
java -cp target/classes io.axisvela.praxo.conformance.Run
java --add-modules jdk.httpserver -cp target/classes:target/test-classes io.axisvela.praxo.adapters.OpenAICompatibleSelfTest
java -cp target/classes:target/test-classes io.axisvela.praxo.agent.AgentConcurrencySelfTest
```

## Usage

```java
import io.axisvela.praxo.agent.Agent;
import io.axisvela.praxo.agent.AgentOptions;
import io.axisvela.praxo.agent.Session;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;
import io.axisvela.praxo.tool.FuncTool;
import io.axisvela.praxo.tool.Registry;

var tools = new Registry();
tools.register(new FuncTool("echo", "Echo", args -> args));

var agent = new Agent(new AgentOptions(request -> Response.of(
        Message.assistant("hello", java.util.List.of()))));
var result = agent.run(new Session("session-1"), "hi");
System.out.println(result.output + " " + result.steps);
```

## Contract Surface

| Package | Contract |
| --- | --- |
| `io.axisvela.praxo.model` | Model, messages, tool specs, request/response, usage |
| `io.axisvela.praxo.tool` | Tool, Registry, FuncTool |
| `io.axisvela.praxo.event` | Event, Sink, multi/filter sinks |
| `io.axisvela.praxo.policy` | Hook, Decision, PathChecker |
| `io.axisvela.praxo.memory` | Store, MemoryRecord, MemoryStore |
| `io.axisvela.praxo.checkpoint` | Allowlist |
| `io.axisvela.praxo.context` | budgets, summarization, offload, AGENTS.md |
| `io.axisvela.praxo.middleware` | call limits, fallback, PII, structured output, tool selection |
| `io.axisvela.praxo.agent` | Agent, AgentOptions, Session, Result |
| `io.axisvela.praxo.toolcall` | tool-call parsing and markup stripping |
| `io.axisvela.praxo.jsonschema` | documented JSON Schema subset |
| `io.axisvela.praxo.plugin` | Manifest v1 parsing and validation |
| `io.axisvela.praxo.adapters` | OpenAI-compatible non-streaming and SSE adapter |

Wire codecs preserve the Go names, including `image_url`, `runId`, and
`plugin_id`. The Java SDK uses a dependency-free JSON utility (`util/Json.java`)
with no runtime dependencies. Model and tool calls run on virtual threads with
`CancellationToken`-based cancellation.

## Conformance

The runner reads `../spec/vectors/*.json`. A released SDK must pass every vector
and keep `spec/parity.md` current.

## License

MIT. See [LICENSE](LICENSE).
