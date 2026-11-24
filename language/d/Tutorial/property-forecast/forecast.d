import core.stdc.stdlib : exit;
import std.stdio;
import praxo.agent;
import praxo.errors : PraxoError, errorCode;
import praxo.json : JSONValue, get, getString, parse, stringify;
import praxo.models;

JSONValue objectOf(JSONValue[string] fields) {
    return JSONValue(fields);
}

class FixtureModel : Model {
    private string site;

    this(string site) {
        this.site = site;
    }

    Response generate(Request request) {
        size_t count = 0;
        JSONValue metrics;
        JSONValue forecast;
        foreach (message; request.messages) {
            if (message.role != TOOL) {
                continue;
            }
            if (count == 0) {
                metrics = parse(message.content);
            }
            forecast = parse(message.content);
            count++;
        }
        if (count == 0) {
            JSONValue[string] arguments;
            arguments["site"] = JSONValue(site);
            return Response(Message.assistant("", [
                ToolCall("metrics-1", "read_site", objectOf(arguments)),
            ]), Usage());
        }
        if (count == 1) {
            JSONValue[string] arguments;
            arguments["site"] = JSONValue(site);
            arguments["action"] = JSONValue("draft_forecast");
            return Response(Message.assistant("", [
                ToolCall("forecast-1", "draft_forecast", objectOf(arguments)),
            ]), Usage());
        }
        JSONValue[string] report;
        report["stage"] = JSONValue("property_forecast_drafted");
        report["metrics"] = metrics;
        report["forecast"] = forecast;
        report["probabilities"] = JSONValue(0);
        report["return_claims"] = JSONValue(0);
        return Response(Message.assistant(stringify(objectOf(report))), Usage());
    }
}

class ReadSiteTool : Tool {
    private bool simulateFailure;
    int reads = 0;

    this(bool simulateFailure) {
        this.simulateFailure = simulateFailure;
    }

    string getName() {
        return "read_site";
    }

    string getDescription() {
        return "Compute fixed site metrics and stated assumptions; no profiling.";
    }

    JSONValue invoke(JSONValue arguments) {
        if (getString(arguments, "site") != "site-100") {
            throw new PraxoError("AGENT_POLICY_DENIED", "only site-100 is in scope");
        }
        reads++;
        if (simulateFailure) {
            throw new PraxoError("SITE_UNAVAILABLE", "synthetic site data unavailable");
        }
        JSONValue[string] value;
        value["site"] = JSONValue("site-100");
        value["footfall"] = JSONValue(8000);
        value["gross_rent"] = JSONValue(240000);
        value["net_income"] = JSONValue(120000);
        value["forecast_yield"] = JSONValue(0.067);
        value["scenarios"] = JSONValue(2);
        value["source"] = JSONValue("site_fixture");
        return objectOf(value);
    }
}

class DraftForecastTool : Tool {
    int drafts = 0;

    string getName() {
        return "draft_forecast";
    }

    string getDescription() {
        return "Draft a review-only forecast; no probability or return claim.";
    }

    JSONValue invoke(JSONValue arguments) {
        if (getString(arguments, "site") != "site-100") {
            throw new PraxoError("AGENT_POLICY_DENIED", "only site-100 is in scope");
        }
        if (getString(arguments, "action") != "draft_forecast") {
            throw new PraxoError("AGENT_POLICY_DENIED", "only draft_forecast is allowed");
        }
        drafts++;
        JSONValue[string] value;
        value["forecast_id"] = JSONValue("property-100");
        value["site"] = get(arguments, "site");
        value["action"] = get(arguments, "action");
        value["scenarios"] = JSONValue(2);
        value["forecast_yield"] = JSONValue(0.067);
        value["status"] = JSONValue("draft_only");
        value["review_required"] = JSONValue(true);
        value["probabilities"] = JSONValue(0);
        value["return_claims"] = JSONValue(0);
        return objectOf(value);
    }
}

Decision authorize(Action action) {
    if (action.kind == "model.generate") {
        return Decision(true);
    }
    if (action.kind == "tool.invoke") {
        return Decision(true);
    }
    return Decision(false, "unsupported action");
}

struct Outcome {
    string output;
    int reads;
    int drafts;
    Throwable error;
}

Outcome runForecast(string site, bool simulateFailure) {
    auto readTool = new ReadSiteTool(simulateFailure);
    auto draftTool = new DraftForecastTool();
    auto registry = new Registry();
    registry.register(readTool);
    registry.register(draftTool);
    auto options = new AgentOptions(new FixtureModel(site));
    options.tools = registry;
    options.maxSteps = 4;
    options.allowedTools = ["read_site", "draft_forecast"];
    options.policy = (Action action) => authorize(action);
    options.requirePolicy = true;
    options.requireToolScope = true;
    try {
        auto result = runAgent(options, Session("property-forecast"),
            "Analyze the fixed site and draft a review-only forecast.");
        return Outcome(result.output, readTool.reads, draftTool.drafts, null);
    } catch (Throwable error) {
        return Outcome("", readTool.reads, draftTool.drafts, error);
    }
}

void runTests() {
    auto success = runForecast("site-100", false);
    if (success.error !is null || success.reads != 1 || success.drafts != 1) {
        stderr.writeln("success failed: reads=", success.reads, " drafts=", success.drafts);
        exit(1);
    }
    auto report = parse(success.output);
    auto metrics = get(report, "metrics");
    auto forecast = get(report, "forecast");
    if (getString(report, "stage") != "property_forecast_drafted" ||
        get(metrics, "gross_rent").integer != 240000 ||
        get(metrics, "net_income").integer != 120000 ||
        get(metrics, "footfall").integer != 8000 ||
        getString(forecast, "status") != "draft_only" ||
        !get(forecast, "review_required").boolean ||
        get(report, "probabilities").integer != 0 ||
        get(report, "return_claims").integer != 0) {
        stderr.writeln("unexpected report: ", success.output);
        exit(1);
    }
    writeln("success: site-100 gross=240000 net=120000 yield=0.067 status=draft_only probabilities=0 reads=1");

    auto denied = runForecast("site-200", false);
    if (denied.error is null || errorCode(denied.error) != "AGENT_POLICY_DENIED" ||
        denied.reads != 0 || denied.drafts != 0) {
        stderr.writeln("deny failed: reads=", denied.reads, " drafts=", denied.drafts);
        exit(1);
    }
    writeln("deny: AGENT_POLICY_DENIED reads=0");

    auto failed = runForecast("site-100", true);
    if (failed.error is null || errorCode(failed.error) != "SITE_UNAVAILABLE" ||
        failed.reads != 1 || failed.drafts != 0) {
        stderr.writeln("failure failed: reads=", failed.reads, " drafts=", failed.drafts);
        exit(1);
    }
    writeln("failure: SITE_UNAVAILABLE reads=1");
}

void main(string[] args) {
    bool testMode = false;
    bool simulateFailure = false;
    string site = "site-100";
    for (size_t index = 1; index < args.length; index++) {
        if (args[index] == "--test") {
            testMode = true;
        } else if (args[index] == "--simulate-failure") {
            simulateFailure = true;
        } else if (args[index] == "--site" && index + 1 < args.length) {
            site = args[++index];
        }
    }
    if (testMode) {
        runTests();
        return;
    }
    auto outcome = runForecast(site, simulateFailure);
    if (outcome.error !is null) {
        stderr.writeln("property forecast failed: reads=", outcome.reads, " drafts=",
            outcome.drafts, "; ", outcome.error.msg);
        exit(1);
    }
    writeln(outcome.output);
}
