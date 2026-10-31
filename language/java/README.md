# PRAXO-CORE Java Core

Java implementation of the PRAXO-CORE contract. The normative contract is
[`spec/`](../../spec/README.md); Go remains the reference implementation.

**Status:** The package passes all eleven conformance vector groups.
Context budgets, middleware, streaming, virtual-thread execution, cancellation,
the OpenAI-compatible adapter, and the agent loop are included. VFS and plugin
hosts are not yet implemented.

Package version: `0.3.0` (source tag `java/v0.3.0`; the earlier
`java/v0.2.3` tag retains `io.axisvela.praxo`). Supported contract:
`SPEC_VERSION` `0.2.0` (`com.axisvela.praxo.Version.SPEC_VERSION`).

Published on Maven Central as `com.axisvela:praxo-core:0.3.0`.

## Install

```xml
<dependency>
  <groupId>com.axisvela</groupId>
  <artifactId>praxo-core</artifactId>
  <version>0.3.0</version>
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
java -cp target/classes:target/test-classes com.axisvela.praxo.agent.AgentConcurrencySelfTest
```

## Usage

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
| `com.axisvela.praxo.toolcall` | tool-call parsing and markup stripping |
| `com.axisvela.praxo.jsonschema` | documented JSON Schema subset |
| `com.axisvela.praxo.plugin` | Manifest v1 parsing and validation |
| `com.axisvela.praxo.adapters` | OpenAI-compatible non-streaming and SSE adapter |

Wire codecs preserve the Go names, including `image_url`, `runId`, and
`plugin_id`. The Java Core uses a dependency-free JSON utility (`util/Json.java`)
with no runtime dependencies. Model and tool calls run on virtual threads with
`CancellationToken`-based cancellation.

## Conformance

The runner reads `../../spec/vectors/*.json`. A released Core implementation must pass every vector
and keep `spec/parity.md` current.

## License

MIT. See [LICENSE](LICENSE).
