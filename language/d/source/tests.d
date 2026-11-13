module tests;

import core.time : Duration;
import std.conv : to;
import std.stdio : writeln;
import std.string : indexOf;
import praxo.agent;
import praxo.anthropic;
import praxo.delegation;
import praxo.errors : PraxoError;
import praxo.gemini;
import praxo.harmovela;
import praxo.openai_compatible;
import praxo.provider : ProviderTransport;
import praxo.jsonschema;
import praxo.json;
import praxo.mcp;
import praxo.middleware;
import praxo.models;
import praxo.otel;
import praxo.plugin;
import praxo.retriever;
import praxo.runtime;
import praxo.toolcall;

void check(bool condition, string message) {
    if (!condition) throw new Error(message);
}

class TestSink : EventSink {
    string[] types;
    void emit(Event event) { types ~= event.type; }
}

class TestModel : Model {
    Message[] steps;
    size_t next = 0;

    this(Message[] steps) { this.steps = steps; }
    Response generate(Request request) { return Response(steps[next++]); }
}

void main() {
    auto call = parseToolCall(`{"name":"echo","input":{"text":"hi"}}`);
    check(call !is null && call.name == "echo" && call.input.object["text"].str == "hi", "toolcall");
    check(stripMarkup(`hello<tool_call name="echo">{"text":"hi"}</tool_call>world`) == "helloworld",
        "toolcall strip");

    auto schema = parse(`{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}`);
    check(validate(schema, parse("{}")).length == 1, "jsonschema");

    auto manifest = parseManifest(`{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},"health":{},"isolation":"process"}`);
    check(manifest.id == "com.example.echo", "plugin");

    auto store = new MemoryStore();
    store.put("s1", new MemoryRecord("m1", "event", "Alpha", "2026-01-01T00:00:00Z"));
    store.put("s1", new MemoryRecord("m2", "event", "ALPHABET", "2026-01-02T00:00:00Z"));
    auto records = store.search("s1", "alpha", 10);
    check(records.length == 2 && records[0].id == "m2", "memory");

    auto allowlist = new CheckpointAllowlist();
    allowlist.register("spec.payload");
    auto data = allowlist.marshal("spec.payload", parse(`{"value":"x"}`));
    check(equals(allowlist.unmarshal(data), parse(`{"value":"x"}`)), "checkpoint");

    auto checker = new PathChecker([PathGrant("root", "readwrite")]);
    check(checker.check("root/a.txt", "read").allowed, "policy allow");
    check(!checker.check("root-evil/x.txt", "read").allowed, "policy sibling");

    Message[] messages = [Message.text(SYSTEM, "sys")];
    foreach (index; 0 .. 10) messages ~= Message.text(USER, "message " ~ index.to!string);
    check(estimateTokens(messages) == 64, "context estimate");
    auto result = compact(ContextBudget(30, 2), messages);
    check(result.ok && estimateTokens(result.messages) == 25, "context compact");

    check((new PiiRedactor()).redact("email a@b.com") == "email [REDACTED:email]", "pii");

    auto registry = new Registry();
    size_t invocations = 0;
    registry.register(new class Tool {
        string getName() { return "echo"; }
        string getDescription() { return "Echo"; }
        JSONValue invoke(JSONValue arguments) { invocations++; return arguments; }
    });
    auto sink = new TestSink();
    auto options = new AgentOptions(new TestModel([
        Message.assistant("", [ToolCall("c1", "echo", parse(`{"text":"hi"}`))]),
        Message.assistant("done"),
    ]));
    options.tools = registry;
    options.events = sink;
    auto runResult = runAgent(options, Session("s1"), "go");
    check(runResult.output == "done" && runResult.steps == 2 && invocations == 1, "agent loop");
    check(sink.types == ["run.started", "tool.call", "run.completed"], "agent events");

    string providerPath = "";
    JSONValue providerPayload = JSONValue.init;
    ProviderTransport openaiTransport = delegate JSONValue(string path, JSONValue payload) {
        providerPath = path;
        providerPayload = payload;
        return parse(`{"choices":[{"message":{"content":"hello","tool_calls":[{"id":"c1","function":{"name":"echo","arguments":"{\"text\":\"hi\"}"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":3,"completion_tokens":4}}`);
    };
    auto openai = new OpenAICompatibleModel(
        "http://example.test/v1", "test-model", "k", openaiTransport);
    Request providerRequest;
    providerRequest.messages = [Message.text(SYSTEM, "be brief"), Message.text(USER, "hi")];
    providerRequest.tools = [ToolSpec("echo", "Echo", parse(`{"type":"object"}`))];
    auto openaiResponse = openai.generate(providerRequest);
    check(providerPath == "/chat/completions", "openai path");
    check(getString(providerPayload, "model") == "test-model", "openai model");
    check(openaiResponse.message.content == "hello", "openai content");
    check(openaiResponse.message.toolCalls[0].arguments.object["text"].str == "hi",
        "openai arguments");

    ProviderTransport anthropicTransport = delegate JSONValue(string path, JSONValue payload) {
        check(path == "/v1/messages", "anthropic path");
        providerPayload = payload;
        return parse(`{"content":[{"type":"text","text":"hello"},{"type":"tool_use","id":"tool-1","name":"echo","input":{"text":"hi"}}],"stop_reason":"end_turn","usage":{"input_tokens":3,"output_tokens":4,"cache_read_input_tokens":2}}`);
    };
    auto anthropic = new AnthropicModel(
        "claude-test", "ak", "http://example.test", "2023-06-01", 1024,
        anthropicTransport);
    auto anthropicResponse = anthropic.generate(providerRequest);
    check(getString(providerPayload, "system") == "be brief", "anthropic system");
    check(anthropicResponse.message.content == "hello", "anthropic content");
    check(anthropicResponse.message.toolCalls[0].arguments.object["text"].str == "hi",
        "anthropic arguments");

    ProviderTransport geminiTransport = delegate JSONValue(string path, JSONValue payload) {
        check(path.length >= 16 && path[$ - 16 .. $] == ":generateContent",
            "gemini path");
        providerPayload = payload;
        return parse(`{"candidates":[{"content":{"parts":[{"text":"hello"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":4}}`);
    };
    auto gemini = new GeminiModel(
        "gemini-test", "gk", "http://example.test", 0, geminiTransport);
    auto geminiResponse = gemini.generate(providerRequest);
    check(get(providerPayload, "system_instruction").type == JSONType.object,
        "gemini system");
    check(geminiResponse.message.content == "hello", "gemini content");
    check(geminiResponse.message.toolCalls[0].name == "echo", "gemini call name");

    string harmovelaPath = "";
    JSONValue harmovelaBody = JSONValue.init;
    HarmovelaTransport harmovelaTransport = delegate HarmovelaResponse(string baseUrl,
        string path, string body, string[string] headers) {
        harmovelaPath = path;
        check(headers["content-type"] == "application/json", "harmovela content type");
        harmovelaBody = parse(body);
        return HarmovelaResponse(204, "");
    };
    HarmovelaClock harmovelaClock = delegate HarmovelaTimestamp() {
        return HarmovelaTimestamp(1700000000L, 123456789);
    };
    auto harmovelaSink = new HarmovelaSink("http://127.0.0.1:8790/aep/api/",
        "praxo-core", "0.2", harmovelaTransport, harmovelaClock);
    harmovelaSink.emit(Event("tool.call", "s1", "run-123", parse(`{"name":"echo"}`)));
    check(harmovelaPath == "/events", "harmovela path");
    check(getString(harmovelaBody, "spec_version") == "0.2", "harmovela spec version");
    check(getString(harmovelaBody, "id") == "run-123-1700000000123456789", "harmovela id");
    check(getString(harmovelaBody, "type") == "tool.call", "harmovela type");
    check(getString(harmovelaBody, "source") == "praxo-core", "harmovela source");
    check(getString(harmovelaBody, "created_at") == "2023-11-14T22:13:20.123456789Z",
        "harmovela created_at");
    auto harmovelaPayload = get(harmovelaBody, "payload");
    check(getString(harmovelaPayload, "name") == "echo", "harmovela payload name");
    check(getString(harmovelaPayload, "session_id") == "s1", "harmovela payload session");
    check(getString(harmovelaPayload, "run_id") == "run-123", "harmovela payload run");

    HarmovelaTransport harmovelaFailure = delegate HarmovelaResponse(string baseUrl,
        string path, string body, string[string] headers) {
        return HarmovelaResponse(500, "boom");
    };
    auto harmovelaFailSink = new HarmovelaSink("http://127.0.0.1:8790/aep/api",
        "praxo-core", "0.2", harmovelaFailure, harmovelaClock);
    string harmovelaCode = "";
    string harmovelaMessage = "";
    try {
        harmovelaFailSink.emit(Event("tool.call", "s1", "run-123", parse(`{"name":"echo"}`)));
    } catch (PraxoError error) {
        harmovelaCode = error.code;
        harmovelaMessage = error.message.to!string;
    }
    check(harmovelaCode == "HARMOVELA_HTTP", "harmovela error code");
    check(harmovelaMessage.indexOf("500") >= 0, "harmovela error status");
    check(harmovelaMessage.indexOf("boom") >= 0, "harmovela error body");

    auto fakeMcp = new FakeMcpTransport();
    auto mcp = new McpClient(fakeMcp, "2025-03-26");
    mcp.start();
    check(mcp.protocolVersion == "2025-03-26", "mcp http protocol version");
    auto mcpTools = mcp.listTools();
    check(mcpTools.length == 1 && mcpTools[0].name == "echo", "mcp http tools");
    auto mcpResult = mcp.callTool("echo", parse(`{"text":"hi"}`));
    check(mcpResult.str == "http-ok", "mcp http call");
    mcp.close();
    check(fakeMcp.closed, "mcp http close");
    string mcpRejected = "";
    try {
        new HttpMcpTransport("http://example.com/mcp");
    } catch (PraxoError error) {
        mcpRejected = error.code;
    }
    check(mcpRejected == "MCP_TRANSPORT", "mcp http https required");

    string otelEndpoint = "";
    JSONValue otelBody = JSONValue.init;
    OtelTransport otelTransport = delegate OtelResponse(string endpoint, string body,
        string[string] headers) {
        otelEndpoint = endpoint;
        check(headers["content-type"] == "application/json", "otel content type");
        otelBody = parse(body);
        return OtelResponse(200, "");
    };
    OtelClock otelClock = delegate long() { return 1700000000123456789L; };
    auto otelSink = new OtelSink("http://127.0.0.1:4318/v1/traces", "praxo-core",
        ["name"], otelTransport, otelClock);
    auto otelEvent = Event("tool.call", "s1", "run-123",
        parse(`{"name":"echo","secret":"hidden"}`));
    otelSink.emit(otelEvent);
    check(otelEndpoint == "http://127.0.0.1:4318/v1/traces", "otel endpoint");
    auto resourceSpans = getArray(otelBody, "resourceSpans");
    check(resourceSpans.length == 1, "otel resource spans");
    auto scopeSpans = getArray(resourceSpans[0], "scopeSpans");
    check(scopeSpans.length == 1, "otel scope spans");
    auto spans = getArray(scopeSpans[0], "spans");
    check(spans.length == 1, "otel spans");
    auto span = spans[0];
    auto firstTrace = getString(span, "traceId");
    auto firstSpan = getString(span, "spanId");
    check(firstTrace.length == 32 && firstSpan.length == 16, "otel ids");
    check(getString(span, "name") == "praxo.tool.call", "otel span name");
    check(getString(span, "startTimeUnixNano") == "1700000000123456789",
        "otel timestamp");
    auto attributeText = stringify(get(span, "attributes"));
    check(attributeText.indexOf("praxo.session.id") >= 0, "otel session attribute");
    check(attributeText.indexOf("praxo.run.id") >= 0, "otel run attribute");
    check(attributeText.indexOf("praxo.event.data.name") >= 0, "otel allowlist");
    check(attributeText.indexOf("hidden") < 0, "otel data excluded");
    otelSink.emit(otelEvent);
    span = getArray(getArray(getArray(otelBody, "resourceSpans")[0], "scopeSpans")[0],
        "spans")[0];
    check(getString(span, "traceId") == firstTrace, "otel deterministic trace");
    check(getString(span, "spanId") == firstSpan, "otel deterministic span");

    string otelUrlCode = "";
    try {
        (new OtelSink("", "praxo-core", [], otelTransport, otelClock)).emit(otelEvent);
    } catch (PraxoError error) {
        otelUrlCode = error.code;
    }
    check(otelUrlCode == "OTEL_URL", "otel endpoint required");

    string otelFailureBody = "boom";
    foreach (index; 0 .. 600) otelFailureBody ~= "x";
    OtelTransport otelFailure = delegate OtelResponse(string endpoint, string body,
        string[string] headers) {
        return OtelResponse(500, otelFailureBody);
    };
    auto otelFailureSink = new OtelSink("http://127.0.0.1:4318/v1/traces",
        "praxo-core", [], otelFailure, otelClock);
    string otelHttpCode = "";
    string otelHttpMessage = "";
    try {
        otelFailureSink.emit(otelEvent);
    } catch (PraxoError error) {
        otelHttpCode = error.code;
        otelHttpMessage = error.message.to!string;
    }
    check(otelHttpCode == "OTEL_HTTP", "otel error code");
    check(otelHttpMessage.indexOf("500") >= 0, "otel error status");
    check(otelHttpMessage.indexOf("boom") >= 0, "otel error body");
    check(otelHttpMessage.length <= 512 + 16, "otel bounded body");

    auto retrieverDocument = Document("doc-1", "alpha",
        parse(`{"source":"test"}`), 0.5);
    check(retrieverDocument.id == "doc-1", "retriever id");
    check(retrieverDocument.content == "alpha", "retriever content");
    check(getString(retrieverDocument.metadata, "source") == "test",
        "retriever metadata");
    check(retrieverDocument.score == 0.5, "retriever score");
    auto retrieverWire = documentWire(retrieverDocument);
    check(getString(retrieverWire, "id") == "doc-1", "retriever wire id");
    check(get(retrieverWire, "score").floating == 0.5, "retriever wire score");

    string retrieverQuery = "";
    long retrieverLimit = -1;
    Retriever retrieverFunction = delegate Document[](string query, long limit) {
        retrieverQuery = query;
        retrieverLimit = limit;
        return [retrieverDocument];
    };
    auto documents = retrieveDocuments(retrieverFunction, "alpha", 3);
    check(retrieverQuery == "alpha" && retrieverLimit == 3, "retriever args");
    check(documents.length == 1 && documents[0].id == "doc-1", "retriever results");
    auto wrappedRetriever = new FuncRetriever(retrieverFunction);
    check(wrappedRetriever.retrieve("beta", 2).length == 1, "retriever func");
    string retrieverCode = "";
    try {
        retrieveDocuments(retrieverFunction, "alpha", -1);
    } catch (PraxoError error) {
        retrieverCode = error.code;
    }
    check(retrieverCode == "RETRIEVER_INVALID", "retriever negative limit");
    retrieverCode = "";
    try {
        retrieveDocuments(null, "alpha", 1);
    } catch (PraxoError error) {
        retrieverCode = error.code;
    }
    check(retrieverCode == "RETRIEVER_INVALID", "retriever function required");

    SubagentClock subagentClock = delegate string() {
        return "2026-11-13T00:00:00Z";
    };
    auto subagentManager = new SubagentManager(
        delegate SubagentResult(SubagentRequest request) {
            check(request.prompt == "hello", "subagent prompt");
            return SubagentResult("child-output");
        }, subagentClock);
    auto subagentTask = subagentManager.run(
        SubagentRequest("parent", "child", "hello"));
    check(subagentTask.status == "completed", "subagent completed");
    check(subagentTask.output == "child-output", "subagent output");
    check(subagentTask.mode == "isolated", "subagent mode");
    check(subagentTask.createdAt == "2026-11-13T00:00:00Z", "subagent created");
    check(subagentTask.updatedAt == "2026-11-13T00:00:00Z", "subagent updated");
    auto forkTask = subagentManager.run(
        SubagentRequest("parent", "child", "hello", JSONValue.init, "fork"));
    check(forkTask.status == "completed" && forkTask.mode == "fork", "subagent fork");
    auto freeTask = runSubagent(
        delegate SubagentResult(SubagentRequest request) {
            return SubagentResult("free-output");
        }, SubagentRequest("parent", "child", "free"));
    check(freeTask.status == "completed" && freeTask.output == "free-output",
        "subagent free function");

    string subagentCode = "";
    try {
        subagentManager.run(SubagentRequest("", "child", "hello"));
    } catch (PraxoError error) {
        subagentCode = error.code;
    }
    check(subagentCode == "SUBAGENT_INVALID", "subagent parent session required");
    subagentCode = "";
    try {
        subagentManager.run(SubagentRequest("parent", "", "hello"));
    } catch (PraxoError error) {
        subagentCode = error.code;
    }
    check(subagentCode == "SUBAGENT_INVALID", "subagent agent id required");
    subagentCode = "";
    try {
        (new SubagentManager(cast(SubagentRunner) null)).run(
            SubagentRequest("parent", "child", "hello"));
    } catch (PraxoError error) {
        subagentCode = error.code;
    }
    check(subagentCode == "SUBAGENT_INVALID", "subagent runner required");

    auto failedManager = new SubagentManager(
        delegate SubagentResult(SubagentRequest request) {
            throw new PraxoError("SUBAGENT_BOOM", "boom");
        }, subagentClock);
    auto failedTask = failedManager.run(
        SubagentRequest("parent", "child", "hello"));
    check(failedTask.status == "failed", "subagent failed");
    check(failedTask.error == "SUBAGENT_BOOM", "subagent error code preserved");
    auto genericManager = new SubagentManager(
        delegate SubagentResult(SubagentRequest request) {
            throw new Exception("boom");
        }, subagentClock);
    auto genericTask = genericManager.run(
        SubagentRequest("parent", "child", "hello"));
    check(genericTask.status == "failed", "subagent generic failed");
    check(genericTask.error == "SUBAGENT_ERROR", "subagent generic error");

    writeln("D core tests passed");
}

class FakeMcpTransport : McpTransport {
    bool closed;
    string notified;

    JSONValue request(string method, JSONValue params, Duration timeout) {
        JSONValue[string] result;
        switch (method) {
            case "initialize":
                result["protocolVersion"] = JSONValue("2025-03-26");
                result["serverInfo"] = emptyObject();
                return JSONValue(result);
            case "tools/list":
                JSONValue[string] tool;
                tool["name"] = JSONValue("echo");
                tool["description"] = JSONValue("Echo input");
                JSONValue[string] schema;
                schema["type"] = JSONValue("object");
                tool["inputSchema"] = JSONValue(schema);
                result["tools"] = JSONValue([JSONValue(tool)]);
                return JSONValue(result);
            case "tools/call":
                JSONValue[string] content;
                content["type"] = JSONValue("text");
                content["text"] = JSONValue("http-ok");
                result["content"] = JSONValue([JSONValue(content)]);
                return JSONValue(result);
            default:
                return emptyObject();
        }
    }

    void notify(string method, JSONValue params) {
        notified = method;
    }

    void close() {
        closed = true;
    }
}
