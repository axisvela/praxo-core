module tests;

import std.conv : to;
import std.stdio : writeln;
import praxo.agent;
import praxo.errors : PraxoError;
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

    writeln("D core tests passed");
}
