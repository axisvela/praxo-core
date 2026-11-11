module tests;

import std.conv : to;
import std.stdio : writeln;
import std.string : indexOf;
import praxo.agent;
import praxo.anthropic;
import praxo.errors : PraxoError;
import praxo.gemini;
import praxo.harmovela;
import praxo.openai_compatible;
import praxo.provider : ProviderTransport;
import praxo.jsonschema;
import praxo.json;
import praxo.middleware;
import praxo.models;
import praxo.plugin;
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

    writeln("D core tests passed");
}
