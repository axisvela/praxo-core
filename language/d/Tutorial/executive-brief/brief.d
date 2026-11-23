import core.stdc.stdlib : exit;
import std.stdio;
import praxo.agent;
import praxo.errors : PraxoError, errorCode;
import praxo.json : JSONValue, JSONType, get, getString, hasKey, parse, stringify;
import praxo.models;

JSONValue objectOf(JSONValue[string] fields) {
    return JSONValue(fields);
}

class FixtureModel : Model {
    private string period;

    this(string period) {
        this.period = period;
    }

    Response generate(Request request) {
        size_t count = 0;
        JSONValue metrics;
        JSONValue brief;
        foreach (message; request.messages) {
            if (message.role != TOOL) {
                continue;
            }
            if (count == 0) {
                metrics = parse(message.content);
            }
            brief = parse(message.content);
            count++;
        }
        if (count == 0) {
            JSONValue[string] arguments;
            arguments["period"] = JSONValue(period);
            return Response(Message.assistant("", [
                ToolCall("metrics-1", "read_metrics", objectOf(arguments)),
            ]), Usage());
        }
        if (count == 1) {
            JSONValue[string] arguments;
            arguments["period"] = JSONValue(period);
            arguments["action"] = JSONValue("send_brief");
            return Response(Message.assistant("", [
                ToolCall("brief-1", "draft_brief", objectOf(arguments)),
            ]), Usage());
        }
        JSONValue[string] report;
        report["stage"] = JSONValue("brief_drafted");
        report["metrics"] = metrics;
        report["brief"] = brief;
        report["sends"] = JSONValue(0);
        return Response(Message.assistant(stringify(objectOf(report))), Usage());
    }
}

class ReadMetricsTool : Tool {
    private bool simulateFailure;
    int reads = 0;

    this(bool simulateFailure) {
        this.simulateFailure = simulateFailure;
    }

    string getName() {
        return "read_metrics";
    }

    string getDescription() {
        return "Compute fixed business-line variances for one period; no writes.";
    }

    JSONValue invoke(JSONValue arguments) {
        reads++;
        if (simulateFailure) {
            throw new PraxoError("METRICS_UNAVAILABLE", "synthetic metrics warehouse unavailable");
        }
        JSONValue[string] value;
        value["period"] = JSONValue("period-100");
        value["revenue_delta"] = JSONValue("-4.2%");
        value["cost_delta"] = JSONValue("+1.5%");
        value["top_variance"] = JSONValue("supply_cost");
        value["source"] = JSONValue("metric_fixture");
        return objectOf(value);
    }
}

class DraftBriefTool : Tool {
    int drafts = 0;

    string getName() {
        return "draft_brief";
    }

    string getDescription() {
        return "Draft a review-only operating brief; never sends it.";
    }

    JSONValue invoke(JSONValue arguments) {
        drafts++;
        JSONValue[string] value;
        value["brief_id"] = JSONValue("brief-100");
        value["period"] = get(arguments, "period");
        value["action"] = get(arguments, "action");
        value["status"] = JSONValue("draft_only");
        value["review_required"] = JSONValue(true);
        value["sends"] = JSONValue(0);
        return objectOf(value);
    }
}

Decision authorize(Action action) {
    if (action.kind == "model.generate") {
        return Decision(true);
    }
    if (action.kind != "tool.invoke") {
        return Decision(false, "unsupported action");
    }
    if (getString(action.arguments, "period") != "period-100") {
        return Decision(false, "only period-100 is in brief scope");
    }
    if (action.toolName == "read_metrics") {
        return Decision(true);
    }
    if (action.toolName == "draft_brief") {
        return Decision(getString(action.arguments, "action") == "send_brief",
            "only a period-100 send_brief draft is allowed");
    }
    return Decision(false, "unsupported tool");
}

struct Outcome {
    string output;
    int reads;
    int drafts;
    Throwable error;
}

Outcome runBrief(string period, bool simulateFailure) {
    auto readTool = new ReadMetricsTool(simulateFailure);
    auto draftTool = new DraftBriefTool();
    auto registry = new Registry();
    registry.register(readTool);
    registry.register(draftTool);
    auto options = new AgentOptions(new FixtureModel(period));
    options.tools = registry;
    options.maxSteps = 4;
    options.allowedTools = ["read_metrics", "draft_brief"];
    options.policy = (Action action) => authorize(action);
    options.requirePolicy = true;
    options.requireToolScope = true;
    try {
        auto result = runAgent(options, Session("executive-brief"),
            "Compute fixed business metrics and draft a review-only brief.");
        return Outcome(result.output, readTool.reads, draftTool.drafts, null);
    } catch (Throwable error) {
        return Outcome("", readTool.reads, draftTool.drafts, error);
    }
}

void runTests() {
    auto success = runBrief("period-100", false);
    if (success.error !is null || success.reads != 1 || success.drafts != 1) {
        stderr.writeln("success failed: reads=", success.reads, " drafts=", success.drafts);
        exit(1);
    }
    auto report = parse(success.output);
    auto metrics = get(report, "metrics");
    auto brief = get(report, "brief");
    if (getString(report, "stage") != "brief_drafted" ||
        getString(metrics, "revenue_delta") != "-4.2%" ||
        getString(metrics, "top_variance") != "supply_cost" ||
        getString(brief, "status") != "draft_only" ||
        get(report, "sends").integer != 0) {
        stderr.writeln("unexpected report: ", success.output);
        exit(1);
    }
    writeln("success: period-100 revenue_delta=-4.2% status=draft_only sends=0 reads=1");

    auto denied = runBrief("period-200", false);
    if (denied.error is null || errorCode(denied.error) != "POLICY_ERROR" ||
        denied.reads != 0 || denied.drafts != 0) {
        stderr.writeln("deny failed: reads=", denied.reads, " drafts=", denied.drafts);
        exit(1);
    }
    writeln("deny: POLICY_ERROR reads=0");

    auto failed = runBrief("period-100", true);
    if (failed.error is null || errorCode(failed.error) != "METRICS_UNAVAILABLE" ||
        failed.reads != 1 || failed.drafts != 0) {
        stderr.writeln("failure failed: reads=", failed.reads, " drafts=", failed.drafts);
        exit(1);
    }
    writeln("failure: METRICS_UNAVAILABLE reads=1");
}

void main(string[] args) {
    bool testMode = false;
    bool simulateFailure = false;
    string period = "period-100";
    for (size_t index = 1; index < args.length; index++) {
        if (args[index] == "--test") {
            testMode = true;
        } else if (args[index] == "--simulate-failure") {
            simulateFailure = true;
        } else if (args[index] == "--period" && index + 1 < args.length) {
            period = args[++index];
        }
    }
    if (testMode) {
        runTests();
        return;
    }
    auto outcome = runBrief(period, simulateFailure);
    if (outcome.error !is null) {
        stderr.writeln("executive brief failed: reads=", outcome.reads,
            " drafts=", outcome.drafts, "; ", outcome.error.msg);
        exit(1);
    }
    writeln(outcome.output);
}
