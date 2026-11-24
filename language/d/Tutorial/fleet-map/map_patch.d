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
    private string fleet;

    this(string fleet) {
        this.fleet = fleet;
    }

    Response generate(Request request) {
        size_t count = 0;
        JSONValue topology;
        JSONValue patch;
        foreach (message; request.messages) {
            if (message.role != TOOL) {
                continue;
            }
            if (count == 0) {
                topology = parse(message.content);
            }
            patch = parse(message.content);
            count++;
        }
        if (count == 0) {
            JSONValue[string] arguments;
            arguments["fleet"] = JSONValue(fleet);
            return Response(Message.assistant("", [
                ToolCall("topology-1", "read_topology", objectOf(arguments)),
            ]), Usage());
        }
        if (count == 1) {
            JSONValue[string] arguments;
            arguments["fleet"] = JSONValue(fleet);
            arguments["action"] = JSONValue("draft_map_patch");
            return Response(Message.assistant("", [
                ToolCall("patch-1", "draft_patch", objectOf(arguments)),
            ]), Usage());
        }
        JSONValue[string] report;
        report["stage"] = JSONValue("map_patch_drafted");
        report["topology"] = topology;
        report["patch"] = patch;
        report["vehicle_takeovers"] = JSONValue(0);
        report["auto_deploys"] = JSONValue(0);
        return Response(Message.assistant(stringify(objectOf(report))), Usage());
    }
}

class ReadTopologyTool : Tool {
    private bool simulateFailure;
    int reads = 0;

    this(bool simulateFailure) {
        this.simulateFailure = simulateFailure;
    }

    string getName() {
        return "read_topology";
    }

    string getDescription() {
        return "Replay fixed synthetic road-topology changes; no vehicle access.";
    }

    JSONValue invoke(JSONValue arguments) {
        if (getString(arguments, "fleet") != "fleet-100") {
            throw new PraxoError("AGENT_POLICY_DENIED", "only fleet-100 is in scope");
        }
        reads++;
        if (simulateFailure) {
            throw new PraxoError("TOPOLOGY_UNAVAILABLE", "synthetic topology unavailable");
        }
        JSONValue[string] value;
        value["fleet"] = JSONValue("fleet-100");
        value["changes"] = JSONValue(2);
        value["confidence"] = JSONValue("medium");
        value["source"] = JSONValue("topology_fixture");
        return objectOf(value);
    }
}

class DraftPatchTool : Tool {
    int drafts = 0;

    string getName() {
        return "draft_patch";
    }

    string getDescription() {
        return "Draft a review-only map patch; never takes over a vehicle.";
    }

    JSONValue invoke(JSONValue arguments) {
        if (getString(arguments, "fleet") != "fleet-100") {
            throw new PraxoError("AGENT_POLICY_DENIED", "only fleet-100 is in scope");
        }
        if (getString(arguments, "action") != "draft_map_patch") {
            throw new PraxoError("AGENT_POLICY_DENIED", "only draft_map_patch is allowed");
        }
        drafts++;
        JSONValue[string] value;
        value["patch_id"] = JSONValue("map-patch-100");
        value["fleet"] = get(arguments, "fleet");
        value["action"] = get(arguments, "action");
        value["changes"] = JSONValue(2);
        value["status"] = JSONValue("draft_only");
        value["review_required"] = JSONValue(true);
        value["vehicle_takeovers"] = JSONValue(0);
        value["auto_deploys"] = JSONValue(0);
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

Outcome runPatch(string fleet, bool simulateFailure) {
    auto readTool = new ReadTopologyTool(simulateFailure);
    auto draftTool = new DraftPatchTool();
    auto registry = new Registry();
    registry.register(readTool);
    registry.register(draftTool);
    auto options = new AgentOptions(new FixtureModel(fleet));
    options.tools = registry;
    options.maxSteps = 4;
    options.allowedTools = ["read_topology", "draft_patch"];
    options.policy = (Action action) => authorize(action);
    options.requirePolicy = true;
    options.requireToolScope = true;
    try {
        auto result = runAgent(options, Session("fleet-map"),
            "Replay the fixed topology changes and draft a review-only map patch.");
        return Outcome(result.output, readTool.reads, draftTool.drafts, null);
    } catch (Throwable error) {
        return Outcome("", readTool.reads, draftTool.drafts, error);
    }
}

void runTests() {
    auto success = runPatch("fleet-100", false);
    if (success.error !is null || success.reads != 1 || success.drafts != 1) {
        stderr.writeln("success failed: reads=", success.reads, " drafts=", success.drafts);
        exit(1);
    }
    auto report = parse(success.output);
    auto topology = get(report, "topology");
    auto patch = get(report, "patch");
    if (getString(report, "stage") != "map_patch_drafted" ||
        get(topology, "changes").integer != 2 ||
        getString(topology, "confidence") != "medium" ||
        getString(patch, "status") != "draft_only" ||
        !get(patch, "review_required").boolean ||
        get(patch, "vehicle_takeovers").integer != 0 ||
        get(report, "auto_deploys").integer != 0) {
        stderr.writeln("unexpected report: ", success.output);
        exit(1);
    }
    writeln("success: fleet-100 changes=2 confidence=medium status=draft_only takeovers=0 reads=1");

    auto denied = runPatch("fleet-200", false);
    if (denied.error is null || errorCode(denied.error) != "AGENT_POLICY_DENIED" ||
        denied.reads != 0 || denied.drafts != 0) {
        stderr.writeln("deny failed: reads=", denied.reads, " drafts=", denied.drafts);
        exit(1);
    }
    writeln("deny: AGENT_POLICY_DENIED reads=0");

    auto failed = runPatch("fleet-100", true);
    if (failed.error is null || errorCode(failed.error) != "TOPOLOGY_UNAVAILABLE" ||
        failed.reads != 1 || failed.drafts != 0) {
        stderr.writeln("failure failed: reads=", failed.reads, " drafts=", failed.drafts);
        exit(1);
    }
    writeln("failure: TOPOLOGY_UNAVAILABLE reads=1");
}

void main(string[] args) {
    bool testMode = false;
    bool simulateFailure = false;
    string fleet = "fleet-100";
    for (size_t index = 1; index < args.length; index++) {
        if (args[index] == "--test") {
            testMode = true;
        } else if (args[index] == "--simulate-failure") {
            simulateFailure = true;
        } else if (args[index] == "--fleet" && index + 1 < args.length) {
            fleet = args[++index];
        }
    }
    if (testMode) {
        runTests();
        return;
    }
    auto outcome = runPatch(fleet, simulateFailure);
    if (outcome.error !is null) {
        stderr.writeln("fleet map failed: reads=", outcome.reads, " drafts=",
            outcome.drafts, "; ", outcome.error.msg);
        exit(1);
    }
    writeln(outcome.output);
}
