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
    private string account;

    this(string account) {
        this.account = account;
    }

    Response generate(Request request) {
        size_t count = 0;
        JSONValue portfolio;
        JSONValue order;
        foreach (message; request.messages) {
            if (message.role != TOOL) {
                continue;
            }
            if (count == 0) {
                portfolio = parse(message.content);
            }
            order = parse(message.content);
            count++;
        }
        if (count == 0) {
            JSONValue[string] arguments;
            arguments["account"] = JSONValue(account);
            return Response(Message.assistant("", [
                ToolCall("portfolio-1", "read_portfolio", objectOf(arguments)),
            ]), Usage());
        }
        if (count == 1) {
            JSONValue[string] arguments;
            arguments["account"] = JSONValue(account);
            arguments["action"] = JSONValue("review_order");
            return Response(Message.assistant("", [
                ToolCall("order-1", "draft_order", objectOf(arguments)),
            ]), Usage());
        }
        JSONValue[string] report;
        report["stage"] = JSONValue("order_review_drafted");
        report["portfolio"] = portfolio;
        report["order"] = order;
        report["trades_executed"] = JSONValue(0);
        return Response(Message.assistant(stringify(objectOf(report))), Usage());
    }
}

class ReadPortfolioTool : Tool {
    private bool simulateFailure;
    int reads = 0;

    this(bool simulateFailure) {
        this.simulateFailure = simulateFailure;
    }

    string getName() {
        return "read_portfolio";
    }

    string getDescription() {
        return "Read a fixed portfolio and compute proposed-order exposure; no trades.";
    }

    JSONValue invoke(JSONValue arguments) {
        if (getString(arguments, "account") != "account-100") {
            throw new PraxoError("AGENT_POLICY_DENIED", "only account-100 is in scope");
        }
        reads++;
        if (simulateFailure) {
            throw new PraxoError("MARKET_DATA_UNAVAILABLE", "synthetic market data unavailable");
        }
        JSONValue[string] value;
        value["account"] = JSONValue("account-100");
        value["shares"] = JSONValue(100);
        value["price"] = JSONValue(50);
        value["risk_limit"] = JSONValue(5000);
        value["proposed_shares"] = JSONValue(200);
        value["exposure"] = JSONValue(10000);
        value["within_limit"] = JSONValue(false);
        value["source"] = JSONValue("portfolio_fixture");
        return objectOf(value);
    }
}

class DraftOrderTool : Tool {
    int drafts = 0;

    string getName() {
        return "draft_order";
    }

    string getDescription() {
        return "Draft a review-only order; never executes a trade.";
    }

    JSONValue invoke(JSONValue arguments) {
        if (getString(arguments, "account") != "account-100") {
            throw new PraxoError("AGENT_POLICY_DENIED", "only account-100 is in scope");
        }
        if (getString(arguments, "action") != "review_order") {
            throw new PraxoError("AGENT_POLICY_DENIED", "only review_order is allowed");
        }
        drafts++;
        JSONValue[string] value;
        value["order_id"] = JSONValue("order-100");
        value["account"] = get(arguments, "account");
        value["action"] = get(arguments, "action");
        value["status"] = JSONValue("draft_only");
        value["review_required"] = JSONValue(true);
        value["within_limit"] = JSONValue(false);
        value["trades_executed"] = JSONValue(0);
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

Outcome runRisk(string account, bool simulateFailure) {
    auto readTool = new ReadPortfolioTool(simulateFailure);
    auto draftTool = new DraftOrderTool();
    auto registry = new Registry();
    registry.register(readTool);
    registry.register(draftTool);
    auto options = new AgentOptions(new FixtureModel(account));
    options.tools = registry;
    options.maxSteps = 4;
    options.allowedTools = ["read_portfolio", "draft_order"];
    options.policy = (Action action) => authorize(action);
    options.requirePolicy = true;
    options.requireToolScope = true;
    try {
        auto result = runAgent(options, Session("quant-risk"),
            "Read fixed market data, enforce the risk limit and draft a review-only order.");
        return Outcome(result.output, readTool.reads, draftTool.drafts, null);
    } catch (Throwable error) {
        return Outcome("", readTool.reads, draftTool.drafts, error);
    }
}

void runTests() {
    auto success = runRisk("account-100", false);
    if (success.error !is null || success.reads != 1 || success.drafts != 1) {
        stderr.writeln("success failed: reads=", success.reads, " drafts=", success.drafts);
        exit(1);
    }
    auto report = parse(success.output);
    auto portfolio = get(report, "portfolio");
    auto order = get(report, "order");
    if (getString(report, "stage") != "order_review_drafted" ||
        get(portfolio, "exposure").integer != 10000 ||
        get(portfolio, "within_limit").boolean ||
        getString(order, "status") != "draft_only" ||
        get(report, "trades_executed").integer != 0) {
        stderr.writeln("unexpected report: ", success.output);
        exit(1);
    }
    writeln("success: account-100 exposure=10000 within_limit=false status=draft_only trades=0 reads=1");

    auto denied = runRisk("account-200", false);
    if (denied.error is null || errorCode(denied.error) != "AGENT_POLICY_DENIED" ||
        denied.reads != 0 || denied.drafts != 0) {
        stderr.writeln("deny failed: reads=", denied.reads, " drafts=", denied.drafts);
        exit(1);
    }
    writeln("deny: AGENT_POLICY_DENIED reads=0");

    auto failed = runRisk("account-100", true);
    if (failed.error is null || errorCode(failed.error) != "MARKET_DATA_UNAVAILABLE" ||
        failed.reads != 1 || failed.drafts != 0) {
        stderr.writeln("failure failed: reads=", failed.reads, " drafts=", failed.drafts);
        exit(1);
    }
    writeln("failure: MARKET_DATA_UNAVAILABLE reads=1");
}

void main(string[] args) {
    bool testMode = false;
    bool simulateFailure = false;
    string account = "account-100";
    for (size_t index = 1; index < args.length; index++) {
        if (args[index] == "--test") {
            testMode = true;
        } else if (args[index] == "--simulate-failure") {
            simulateFailure = true;
        } else if (args[index] == "--account" && index + 1 < args.length) {
            account = args[++index];
        }
    }
    if (testMode) {
        runTests();
        return;
    }
    auto outcome = runRisk(account, simulateFailure);
    if (outcome.error !is null) {
        stderr.writeln("quant risk failed: reads=", outcome.reads, " drafts=",
            outcome.drafts, "; ", outcome.error.msg);
        exit(1);
    }
    writeln(outcome.output);
}
