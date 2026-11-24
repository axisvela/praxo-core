import core.stdc.stdlib : exit;
import std.conv : to;
import std.stdio;
import std.string : split, splitLines, strip;
import std.exception : enforce;
import praxo.agent;
import praxo.errors : PraxoError, errorCode;
import praxo.json : JSONValue, get, getString, parse, stringify;
import praxo.models;

enum fixture = "id,amount\na,12\nb,invalid\nc,-3\nd,8\nbroken\n";

JSONValue analyze(string input) {
    auto lines = input.splitLines;
    enforce(lines.length > 0 && lines[0].strip == "id,amount", "invalid header");
    int valid, invalid, total;
    JSONValue[] errors;
    foreach (index, line; lines[1 .. $]) {
        if (line.strip.length == 0) continue;
        string reason;
        auto cells = line.split(",");
        if (cells.length != 2) reason = "field_count";
        else if (cells[0].strip.length == 0) reason = "missing_id";
        else {
            try {
                auto amount = cells[1].strip.to!int;
                if (amount < 0) reason = "negative_amount";
                else { total += amount; valid++; }
            } catch (Exception e) { reason = "invalid_integer"; }
        }
        if (reason.length) {
            invalid++;
            errors ~= JSONValue(["line": JSONValue(cast(int) index + 2),
                                  "reason": JSONValue(reason)]);
        }
    }
    return JSONValue(["valid": JSONValue(valid), "invalid": JSONValue(invalid),
                      "total": JSONValue(total), "errors": JSONValue(errors)]);
}

class PipelineModel : Model {
    string batch;
    this(string batch) { this.batch = batch; }
    Response generate(Request request) {
        JSONValue[] results;
        foreach (message; request.messages)
            if (message.role == TOOL) results ~= parse(message.content);
        if (results.length == 0)
            return Response(Message.assistant("", [ToolCall("read-1", "analyze_batch",
                JSONValue(["batch": JSONValue(batch)]))]), Usage());
        if (results.length == 1) {
            auto action = get(results[0], "invalid").integer > 0 ? "review_rejections" : "review_import";
            return Response(Message.assistant("", [ToolCall("draft-1", "draft_review",
                JSONValue(["batch": JSONValue(batch), "action": JSONValue(action)]))]), Usage());
        }
        return Response(Message.assistant(stringify(JSONValue([
            "analysis": results[0], "review": results[1], "imports": JSONValue(0)]))), Usage());
    }
}

class AnalyzeBatch : Tool {
    string input;
    bool fail;
    int calls;
    this(string input, bool fail) { this.input = input; this.fail = fail; }
    string getName() { return "analyze_batch"; }
    string getDescription() { return "Parse fixed unquoted two-column CSV and calculate errors; no file writes."; }
    JSONValue invoke(JSONValue args) {
        if (getString(args, "batch") != "batch-100")
            throw new PraxoError("AGENT_POLICY_DENIED", "batch outside scope");
        calls++;
        if (fail) throw new PraxoError("BATCH_UNAVAILABLE", "fixture source unavailable");
        try { return analyze(input); }
        catch (Exception e) { throw new PraxoError("BATCH_FORMAT_INVALID", "invalid batch header"); }
    }
}

class DraftReview : Tool {
    int calls;
    string getName() { return "draft_review"; }
    string getDescription() { return "Draft a reviewed import or rejection action; never imports records."; }
    JSONValue invoke(JSONValue args) {
        auto action = getString(args, "action");
        if (getString(args, "batch") != "batch-100" ||
            (action != "review_rejections" && action != "review_import"))
            throw new PraxoError("AGENT_POLICY_DENIED", "draft outside scope");
        calls++;
        return JSONValue(["action": JSONValue(action), "status": JSONValue("draft_only"),
                          "review_required": JSONValue(true), "imports": JSONValue(0)]);
    }
}

struct Outcome { string output; int reads; int drafts; string code; }

Outcome run(string batch, string input, bool fail = false) {
    auto reader = new AnalyzeBatch(input, fail);
    auto draft = new DraftReview;
    auto registry = new Registry;
    registry.register(reader);
    registry.register(draft);
    auto options = new AgentOptions(new PipelineModel(batch));
    options.tools = registry;
    options.allowedTools = ["analyze_batch", "draft_review"];
    options.requirePolicy = true;
    options.requireToolScope = true;
    options.maxSteps = 4;
    options.policy = (Action action) => Decision(
        action.kind == "model.generate" || action.kind == "tool.invoke");
    try {
        auto result = runAgent(options, Session("data-pipeline"), "Analyze the batch and draft its review.");
        return Outcome(result.output, reader.calls, draft.calls, "");
    } catch (Throwable e) { return Outcome("", reader.calls, draft.calls, errorCode(e)); }
}

void test() {
    auto result = run("batch-100", fixture);
    enforce(result.code == "" && result.reads == 1 && result.drafts == 1, "success counts");
    auto report = parse(result.output);
    auto analysis = get(report, "analysis");
    enforce(get(analysis, "valid").integer == 2 && get(analysis, "invalid").integer == 3, "record counts");
    enforce(get(analysis, "total").integer == 20 && get(analysis, "errors").array.length == 3, "calculation");
    enforce(getString(get(report, "review"), "action") == "review_rejections", "rejection branch");
    auto clean = parse(run("batch-100", "id,amount\nx,7\ny,4\n").output);
    enforce(get(get(clean, "analysis"), "total").integer == 11, "changed input");
    enforce(getString(get(clean, "review"), "action") == "review_import", "clean branch");
    auto denied = run("batch-200", fixture);
    enforce(denied.code == "AGENT_POLICY_DENIED" && denied.reads == 0 && denied.drafts == 0, "scope");
    auto failed = run("batch-100", fixture, true);
    enforce(failed.code == "BATCH_UNAVAILABLE" && failed.reads == 1 && failed.drafts == 0, "dependency");
    auto malformed = run("batch-100", "unexpected\nx,3");
    enforce(malformed.code.length > 0 && malformed.drafts == 0, "header failure");
    enforce(get(analyze("id,amount\n,2\n"), "invalid").integer == 1, "missing identifier");
    writeln("D data-pipeline tutorial: parsing, branches, denial and failure passed");
}

void main(string[] args) {
    if (args.length > 1 && args[1] == "--test") { test(); return; }
    string batch = "batch-100";
    bool fail;
    foreach (index, arg; args) {
        if (arg == "--batch" && index + 1 < args.length) batch = args[index + 1];
        if (arg == "--simulate-failure") fail = true;
    }
    auto result = run(batch, fixture, fail);
    if (result.code.length) {
        stderr.writeln(result.code, " reads=", result.reads, " drafts=", result.drafts);
        exit(1);
    }
    writeln(result.output);
}
