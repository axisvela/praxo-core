module conformance;

import std.algorithm : sort;
import std.array : join;
import std.conv : to;
import std.file : exists, readText;
import std.string : strip;
import std.stdio : stderr, writeln;
import praxo.agent;
import praxo.errors : PraxoError, errorCode;
import praxo.jsonschema;
import praxo.json;
import praxo.middleware;
import praxo.models;
import praxo.plugin;
import praxo.runtime;
import praxo.toolcall;

class RecordingSink : EventSink {
    string[] types;

    void emit(Event event) {
        types ~= event.type;
    }
}

class ScriptedModel : Model {
    JSONValue[] steps;
    size_t next = 0;

    this(JSONValue[] steps) {
        this.steps = steps;
    }

    Response generate(Request request) {
        if (next >= steps.length) throw new PraxoError("SCRIPT", "script exhausted");
        auto step = steps[next++];
        ToolCall[] calls;
        foreach (item; getArray(step, "toolCalls")) {
            calls ~= ToolCall(getString(item, "id") is null ? "" : getString(item, "id"),
                getString(item, "name") is null ? "" : getString(item, "name"),
                get(item, "arguments"));
        }
        return Response(Message.assistant(getString(step, "content") is null ? "" : getString(step, "content"), calls),
            Usage(getInt(step, "inputTokens"), getInt(step, "outputTokens")));
    }
}

class EchoTool : Tool {
    private string name;
    private string description;
    private size_t* invocations;

    this(string name, string description, size_t* invocations) {
        this.name = name;
        this.description = description;
        this.invocations = invocations;
    }

    string getName() { return name; }
    string getDescription() { return description; }
    JSONValue invoke(JSONValue arguments) {
        (*invocations)++;
        return arguments;
    }
}

void check(bool condition, string message) {
    if (!condition) throw new PraxoError("CONFORMANCE", message);
}

string readSpec(string path) {
    return exists(path) ? readText(path) : readText("../../" ~ path);
}

void runToolcall(JSONValue input, JSONValue expect) {
    auto operation = getString(input, "operation");
    auto content = getString(input, "content");
    if (operation == "strip") {
        auto got = stripMarkup(content is null ? "" : content);
        check(got == (getString(expect, "text") is null ? "" : getString(expect, "text")), "strip: got " ~ got);
        return;
    }
    auto call = parseToolCall(content is null ? "" : content);
    if (getBool(expect, "nil")) {
        check(call is null, "expected nil");
        return;
    }
    check(call !is null, "expected a tool call");
    check(call.name == (getString(expect, "name") is null ? "" : getString(expect, "name")),
        "name: got " ~ call.name);
    auto expected = get(expect, "input");
    if (expected.type != JSONType.object) expected = JSONValue(cast(JSONValue[string]) null);
    check(equals(call.input, expected), "input mismatch");
}

void runJsonschema(JSONValue input, JSONValue expect) {
    auto errors = validate(get(input, "schema"), get(input, "data"));
    string[] paths;
    foreach (error; errors) paths ~= error.path;
    paths.sort();
    string[] expected;
    foreach (item; getArray(expect, "errorPaths")) expected ~= item.str;
    expected.sort();
    check((errors.length == 0) == getBool(expect, "valid"), "valid mismatch");
    check(paths == expected, "errorPaths: got " ~ paths.join(", "));
}

void runPlugin(JSONValue input, JSONValue expect) {
    auto raw = getString(input, "raw");
    if (raw is null) raw = stringify(get(input, "manifest"));
    PluginManifest manifest;
    bool valid = false;
    try {
        manifest = parseManifest(raw);
        valid = true;
    } catch (Exception) {}
    check(valid == getBool(expect, "valid"), "valid mismatch");
    if (!valid) return;
    auto id = getString(expect, "id");
    if (id !is null) check(manifest.id == id, "id: got " ~ manifest.id);
    auto kind = getString(expect, "kind");
    if (kind !is null) check(manifest.kind == kind, "kind: got " ~ manifest.kind);
}

void runMemory(JSONValue input, JSONValue expect) {
    auto store = new MemoryStore();
    foreach (put; getArray(input, "puts")) {
        auto record = get(put, "record");
        store.put(getString(put, "session"), new MemoryRecord(
            getString(record, "id") is null ? "" : getString(record, "id"),
            getString(record, "frame") is null ? "" : getString(record, "frame"),
            getString(record, "content") is null ? "" : getString(record, "content"),
            getString(record, "createdAt")));
    }
    auto records = store.search(getString(input, "session"), getString(input, "query"),
        getInt(input, "limit"));
    auto expectedIds = get(expect, "ids");
    auto expectedContents = get(expect, "contents");
    if (expectedIds.type == JSONType.null_) {
        check(records.length == 0, "ids mismatch");
        return;
    }
    check(records.length == expectedIds.array.length, "ids mismatch");
    foreach (index, record; records) {
        check(record.id == expectedIds.array[index].str, "ids mismatch");
        if (expectedContents.type == JSONType.array) {
            check(record.content == expectedContents.array[index].str, "contents mismatch");
        }
    }
}

void runEvent(JSONValue input, JSONValue expect) {
    Event[] events;
    foreach (item; getArray(input, "events")) events ~= Event(item.str, "s1");
    if (getString(input, "sink") == "multi") {
        auto count = getInt(input, "sinkCount", 1);
        if (count < 1) count = 1;
        RecordingSink[] sinks;
        EventSink[] sinkValues;
        foreach (_; 0 .. count) {
            auto sink = new RecordingSink();
            sinks ~= sink;
            sinkValues ~= sink;
        }
        auto multi = new MultiSink(sinkValues);
        foreach (event; events) multi.emit(event);
        JSONValue[] perSink;
        foreach (sink; sinks) {
            JSONValue[] types;
            foreach (kind; sink.types) types ~= JSONValue(kind);
            perSink ~= JSONValue(types);
        }
        check(equals(JSONValue(perSink), get(expect, "perSink")), "perSink mismatch");
        return;
    }
    auto sink = new RecordingSink();
    auto predicateTypes = get(input, "predicateTypes");
    string[string] allowed;
    if (predicateTypes.type == JSONType.array) {
        foreach (item; predicateTypes.array) allowed[item.str] = item.str;
    }
    auto filter = new FilterSink(sink, delegate bool(Event event) {
        return predicateTypes.type != JSONType.array || (event.type in allowed) !is null;
    });
    foreach (event; events) filter.emit(event);
    JSONValue delivered = sink.types.length == 0 ? JSONValue(null) : JSONValue(sink.types);
    check(equals(delivered, get(expect, "delivered")), "delivered mismatch");
}

void runStream(JSONValue expect) {
    JSONValue[] kinds;
    foreach (kind; streamKinds) kinds ~= JSONValue(kind);
    check(equals(JSONValue(kinds), get(expect, "kinds")), "kinds mismatch");
}

void runCheckpoint(JSONValue input, JSONValue expect) {
    auto allowlist = new CheckpointAllowlist();
    foreach (item; getArray(input, "registered")) allowlist.register(item.str);
    auto operation = getString(input, "operation");
    if (operation is null) operation = "roundtrip";
    auto payloadType = getString(input, "type");
    if (payloadType is null) payloadType = "";
    auto value = get(input, "value");
    if (operation == "roundtrip") {
        auto data = allowlist.marshal(payloadType, value);
        check(equals(allowlist.unmarshal(data), get(expect, "value")), "value mismatch");
        return;
    }
    string code = "";
    try {
        if (operation == "marshal") allowlist.marshal(payloadType, value);
        else if (operation == "unmarshal") {
            JSONValue[string] envelope;
            envelope["type"] = JSONValue(payloadType);
            envelope["data"] = value;
            allowlist.unmarshal(stringify(JSONValue(envelope)));
        } else throw new PraxoError("CHECKPOINT_ERROR", "unknown operation");
    } catch (PraxoError error) {
        code = error.code;
    }
    check(code == (getString(expect, "errorCode") is null ? "" : getString(expect, "errorCode")),
        "errorCode: got " ~ code);
}

void runPolicy(JSONValue input, JSONValue expect) {
    auto root = "praxo-policy";
    PathGrant[] grants;
    foreach (item; getArray(input, "grants")) {
        grants ~= PathGrant(root ~ "/" ~ getString(item, "root"),
            getString(item, "access") is null ? "read" : getString(item, "access"));
    }
    auto checker = new PathChecker(grants);
    auto target = root ~ "/" ~ getString(input, "target");
    auto need = getString(input, "need");
    if (need is null) need = "read";
    if (getBool(expect, "error")) {
        try {
            checker.check(target, need);
        } catch (PraxoError error) {
            check(error.code == "POLICY_ERROR", "expected policy error");
            return;
        }
        check(false, "expected a policy error");
        return;
    }
    check(checker.check(target, need).allowed == getBool(expect, "allowed"), "allowed mismatch");
}

void runContext(JSONValue input, JSONValue expect) {
    Message[] messages;
    foreach (item; getArray(input, "messages")) {
        messages ~= Message.text(getString(item, "role"), getString(item, "content"));
    }
    if (getString(input, "operation") == "estimate") {
        auto tokens = estimateTokens(messages);
        check(tokens == getInt(expect, "tokens"), "tokens: got " ~ tokens.to!string);
        return;
    }
    auto budgetJson = get(input, "budget");
    auto budget = ContextBudget(getInt(budgetJson, "maxTokens"), getInt(budgetJson, "keepRecent"));
    auto result = compact(budget, messages);
    check(result.ok == getBool(expect, "ok"), "ok mismatch");
    if (!result.ok) return;
    auto tokens = estimateTokens(result.messages);
    check(tokens == getInt(expect, "tokens"), "tokens: got " ~ tokens.to!string);
    JSONValue[] wires;
    foreach (message; result.messages) wires ~= messageWire(message);
    check(equals(JSONValue(wires), get(expect, "messages")), "messages mismatch");
}

void runMiddleware(JSONValue input, JSONValue expect) {
    auto operation = getString(input, "operation");
    auto redactor = new PiiRedactor();
    if (operation == "pii") {
        auto got = redactor.redact(getString(input, "text"));
        check(got == (getString(expect, "text") is null ? "" : getString(expect, "text")), "text mismatch");
    } else if (operation == "pii-value") {
        check(equals(redactor.redactValue(get(input, "value")), get(expect, "value")), "value mismatch");
    } else if (operation == "structured") {
        auto repairOutput = getString(input, "repairOutput");
        auto output = new StructuredOutput(get(input, "schema"), getInt(input, "maxRepairs"),
            repairOutput is null ? null : delegate string(string text) { return repairOutput; });
        auto result = output.apply(getString(input, "output"));
        if (getBool(expect, "ok")) check(result.output == getString(expect, "output"), "output mismatch");
        else check(result.errorCode == getString(expect, "errorCode"), "errorCode mismatch");
    } else if (operation == "call-limit") {
        auto limit = new CallLimit(getInt(input, "modelLimit"), getInt(input, "toolLimit"));
        JSONValue[] outcomes;
        foreach (call; getArray(input, "calls")) {
            string code = "ok";
            try {
                if (call.str == "model") limit.beforeModel();
                else limit.beforeTool();
            } catch (PraxoError error) {
                code = error.code;
            }
            outcomes ~= JSONValue(code);
        }
        check(equals(JSONValue(outcomes), get(expect, "outcomes")), "outcomes mismatch");
    } else if (operation == "tool-selection") {
        string[] selected;
        foreach (item; getArray(input, "selected")) selected ~= item.str;
        auto selection = new ToolSelection(selected);
        ToolSpec[] tools;
        foreach (item; getArray(input, "tools")) tools ~= ToolSpec(item.str);
        JSONValue[] advertised;
        foreach (tool; selection.filter(tools)) advertised ~= JSONValue(tool.name);
        check(equals(JSONValue(advertised), get(expect, "advertised")), "advertised mismatch");
        string reject = "ok";
        try selection.reject(getString(input, "requested"));
        catch (PraxoError error) reject = error.code;
        check(reject == getString(expect, "reject"), "reject mismatch");
    } else if (operation == "fallback") {
        auto content = getString(input, "fallbackContent");
        ModelHandler fallback = delegate Response(Request request) {
            return Response(Message.assistant(content));
        };
        ModelHandler next = delegate Response(Request request) {
            throw new PraxoError("PRIMARY_FAILED", "primary");
        };
        auto handler = fallbackModel(fallback)(next);
        check(handler(Request()).message.content == content, "output mismatch");
    } else {
        throw new PraxoError("CONFORMANCE", "unknown middleware operation");
    }
}

void runAgentLoop(JSONValue input, JSONValue expect) {
    size_t invocations = 0;
    auto registry = new Registry();
    foreach (item; getArray(input, "tools")) {
        registry.register(new EchoTool(getString(item, "name"), getString(item, "description"), &invocations));
    }
    auto sink = new RecordingSink();
    auto model = new ScriptedModel(getArray(input, "script"));
    auto options = new AgentOptions(model);
    options.tools = registry;
    options.events = sink;
    options.maxSteps = getInt(input, "maxSteps");
    options.maxTokens = getInt(input, "maxTokens");
    RunResult result;
    string failure;
    try {
        result = runAgent(options, Session("s1"), getString(input, "prompt"));
    } catch (PraxoError error) {
        failure = error.code;
    }
    if (getBool(expect, "error")) {
        check(failure.length > 0, "unexpected success");
        auto expected = getString(expect, "errorCode");
        if (expected !is null) check(failure == expected, "errorCode mismatch");
    } else {
        check(failure.length == 0, "unexpected failure: " ~ failure);
        check(result.output == (getString(expect, "output") is null ? "" : getString(expect, "output")), "output mismatch");
        check(result.steps == getInt(expect, "steps"), "steps mismatch");
    }
    check(invocations == getInt(expect, "toolInvocations"), "tool invocations mismatch");
    JSONValue events = sink.types.length == 0 ? JSONValue(null) : JSONValue(sink.types);
    check(equals(events, get(expect, "events")), "events mismatch");
}

void runVector(string group, JSONValue vector) {
    auto input = get(vector, "input");
    auto expect = get(vector, "expect");
    if (group == "toolcall") runToolcall(input, expect);
    else if (group == "jsonschema") runJsonschema(input, expect);
    else if (group == "plugin") runPlugin(input, expect);
    else if (group == "memory") runMemory(input, expect);
    else if (group == "event") runEvent(input, expect);
    else if (group == "stream") runStream(expect);
    else if (group == "checkpoint") runCheckpoint(input, expect);
    else if (group == "policy") runPolicy(input, expect);
    else if (group == "context") runContext(input, expect);
    else if (group == "middleware") runMiddleware(input, expect);
    else if (group == "agent-loop") runAgentLoop(input, expect);
    else throw new PraxoError("CONFORMANCE", "no runner for group " ~ group);
}

void main() {
    string[] groups = ["toolcall", "jsonschema", "plugin", "memory", "event", "stream",
        "checkpoint", "policy", "context", "middleware", "agent-loop"];
    auto specVersion = readSpec("spec/SPEC_VERSION").strip();
    string[] failures;
    foreach (group; groups) {
        auto file = parse(readSpec("spec/vectors/" ~ group ~ ".json"));
        if (getString(file, "group") != group) failures ~= group ~ ": group mismatch";
        if (getString(file, "specVersion") != specVersion) failures ~= group ~ ": specVersion mismatch";
        foreach (vector; getArray(file, "vectors")) {
            auto id = getString(vector, "id");
            try {
                runVector(group, vector);
            } catch (Exception error) {
                failures ~= group ~ "/" ~ id ~ ": " ~ error.msg;
            }
        }
    }
    if (failures.length == 0) {
        writeln("all spec vectors passed");
        return;
    }
    foreach (failure; failures) stderr.writeln(failure);
    throw new Exception("conformance failed");
}
