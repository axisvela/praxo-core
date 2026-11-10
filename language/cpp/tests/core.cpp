#include <algorithm>
#include <cassert>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <future>
#include <iostream>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <thread>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"
#include "praxo/jsonschema.hpp"
#include "praxo/middleware.hpp"
#include "praxo/models.hpp"
#include "praxo/openai_compat.hpp"
#include "praxo/plugin.hpp"
#include "praxo/runtime.hpp"
#include "praxo/sse.hpp"
#include "praxo/toolcall.hpp"

using namespace praxo;

namespace {

class TestModel : public Model {
public:
    explicit TestModel(Json steps) : steps_(std::move(steps)) {}
    Response generate(const Request& request) override {
        (void)request;
        const Json& step = steps_.as_array()[next_++];
        Response response;
        response.message = assistant_message(step.at("content").as_string());
        if (step.contains("toolCalls")) {
            for (const auto& item : step.at("toolCalls").as_array()) {
                ToolCall call;
                call.id = item.at("id").as_string();
                call.name = item.at("name").as_string();
                call.arguments = item.at("arguments");
                response.message.tool_calls.push_back(call);
            }
        }
        return response;
    }

private:
    Json steps_;
    std::size_t next_ = 0;
};

class RespondModel : public Model {
public:
    Response generate(const Request& request) override {
        if (step_++ == 0) {
            ToolCall call;
            call.id = "c1";
            call.name = "echo";
            call.arguments = Json::parse(R"({"value":"original"})");
            Response response;
            response.message = assistant_message("");
            response.message.tool_calls.push_back(call);
            return response;
        }
        std::string content = "final";
        for (auto it = request.messages.rbegin(); it != request.messages.rend(); ++it) {
            if (it->role == TOOL && it->content) {
                content = *it->content;
                break;
            }
        }
        Response response;
        response.message = assistant_message(content);
        return response;
    }

private:
    int step_ = 0;
};

void check(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}


class FailingModel : public Model {
public:
    Response generate(const Request& request) override {
        (void)request;
        throw PraxoError("RUN_FAILED", "run failed");
    }
};

class RecordingSink : public EventSink {
public:
    std::vector<std::string> types;
    void emit(const Event& event) override { types.push_back(event.type); }
};

class CancelModel : public Model {
public:
    explicit CancelModel(bool& flag) : flag_(flag) {}
    Response generate(const Request& request) override {
        (void)request;
        flag_ = true;
        Response response;
        response.message = assistant_message("done");
        return response;
    }

private:
    bool& flag_;
};

class ParallelModel : public Model {
public:
    std::vector<std::string> order;

    Response generate(const Request& request) override {
        Response response;
        if (!called_) {
            called_ = true;
            response.message = assistant_message("");
            ToolCall a;
            a.id = "c1";
            a.name = "a";
            ToolCall b;
            b.id = "c2";
            b.name = "b";
            response.message.tool_calls = {a, b};
            return response;
        }
        for (const auto& message : request.messages) {
            if (message.role == TOOL && message.tool_id) {
                order.push_back(*message.tool_id);
            }
        }
        response.message = assistant_message("done");
        return response;
    }

private:
    bool called_ = false;
};

}  // namespace

int main() {
    try {
        auto call = parse_toolcall(R"({"name":"echo","input":{"text":"hi"}})");
        check(call.has_value(), "toolcall parsed");
        check(call->name == "echo", "toolcall name");
        check(call->input == Json::parse(R"({"text":"hi"})"), "toolcall input");
        check(strip_markup(
            "hello<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>world") ==
            "helloworld", "toolcall stripped");

        Json schema = Json::parse(
            R"({"type":"object","properties":{"name":{"type":"string"}},"required":["name"]})");
        auto errors = validate(schema, Json::object());
        check(errors.size() == 1 && errors[0].path == "$.name", "schema required");
        check(validate(schema, Json::parse(R"({"name":"ok"})")).empty(), "schema valid");
        Json unicode_schema = Json::parse(
            R"({"type":"string","minLength":2,"maxLength":2})");
        check(validate(unicode_schema, Json("你好")).empty(), "schema unicode two");
        check(validate(unicode_schema, Json("你")).size() == 1, "schema unicode one");
        Json integer_schema = Json::parse(R"({"type":"integer"})");
        check(validate(integer_schema, Json(2)).empty(), "schema integer");
        check(validate(integer_schema, Json(2.5)).size() == 1, "schema integer fraction");

        auto manifest = parse_manifest(
            R"({"schemaVersion":1,"id":"com.example.echo","version":"1.0.0",)"
            R"("kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},)"
            R"("protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},)"
            R"("health":{},"isolation":"process"})");
        check(manifest.id == "com.example.echo", "plugin manifest");

        MemoryStore store;
        store.put("s1", {"m1", "event", "Alpha", "2026-01-01T00:00:00Z"});
        store.put("s1", {"m2", "event", "ALPHABET", "2026-01-02T00:00:00Z"});
        auto records = store.search("s1", "alpha", 10);
        check(records.size() == 2 && records[0].id == "m2" && records[1].id == "m1", "memory");

        CheckpointAllowlist allowlist;
        allowlist.register_type("spec.payload");
        check(allowlist.unmarshal(allowlist.marshal("spec.payload",
            Json::parse(R"({"value":"x"})"))) == Json::parse(R"({"value":"x"})"),
            "checkpoint");

        auto root = std::filesystem::temp_directory_path() /
            ("praxo-cpp-tests-" + std::to_string(
                std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::system_clock::now().time_since_epoch()).count()));
        std::filesystem::create_directories(root / "root");
        std::filesystem::create_directories(root / "root-evil");
        PathChecker checker({{(root / "root").string(), "readwrite"}});
        check(checker.check((root / "root" / "a.txt").string(), "read").allowed, "policy allow");
        check(!checker.check((root / "root-evil" / "x.txt").string(), "read").allowed,
              "policy sibling");
        std::filesystem::remove_all(root);

        auto messages = [&]() {
            std::vector<Message> out;
            out.push_back(text_message(SYSTEM, "sys"));
            for (int i = 0; i < 10; ++i) out.push_back(text_message(USER, "message " + std::to_string(i)));
            return out;
        }();
        check(estimate_tokens(messages) == 64, "context estimate");
        ContextBudget budget{30, 2};
        auto [compacted, ok] = budget.compact(messages);
        check(ok, "context compact");
        check(estimate_tokens(compacted) == 25, "context compact tokens");
        check(compacted[1].content.value_or("") ==
              "[context compacted: 8 older messages omitted]", "context marker");

        check(PiiRedactor().redact("email a@b.com") == "email [REDACTED:email]", "pii");
        Json pii_history = Json::parse(
            R"({"messages":[{"content":"email a@b.com","toolCalls":[)"
            R"({"arguments":{"email":"a@b.com","nested":{"ssn":"123-45-6789"}}}]}]})");
        Json redacted_history = PiiRedactor().redact_value(pii_history);
        check(redacted_history.dump().find("[REDACTED:email]") != std::string::npos,
              "pii tool history email");
        check(redacted_history.dump().find("[REDACTED:ssn]") != std::string::npos,
              "pii tool history nested ssn");
        check(pii_history.dump().find("a@b.com") != std::string::npos,
              "pii input unchanged");
        Json structured_schema = Json::parse(
            R"({"type":"object","properties":{"value":{"type":"integer"}},"required":["value"]})");
        StructuredOutput structured(structured_schema, 0);
        auto [text, code] = structured.apply(R"({"value":1})");
        check(text.has_value() && *text == R"({"value":1})" && !code, "structured");

        CallLimit limit(1, 0);
        limit.before_model();
        bool caught = false;
        try { limit.before_model(); } catch (const PraxoError&) { caught = true; }
        check(caught, "call limit");

        CallLimit tool_limit(0, 1);
        tool_limit.before_tool();
        caught = false;
        try { tool_limit.before_tool(); } catch (const PraxoError&) { caught = true; }
        check(caught, "tool call limit");

        bool capacity_caught = false;
        try {
            AgentOptions tight(std::make_shared<StaticModel>("done"));
            tight.system_prompt = std::string(1000, 'x');
            tight.context = ContextBudget{10, 0};
            (void)run_agent(std::move(tight), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            capacity_caught = error.code() == "AGENT_CONTEXT_BUDGET";
        }
        check(capacity_caught, "capacity fail closed");

        ToolSelection selection({"echo"});
        std::vector<ToolSpec> tools;
        tools.push_back({"echo", "Echo", Json(nullptr), std::nullopt});
        tools.push_back({"other", "Other", Json(nullptr), std::nullopt});
        check(selection.filter(tools).size() == 1, "tool selection");
        caught = false;
        try { selection.reject("other"); } catch (const PraxoError&) { caught = true; }
        check(caught, "tool selection reject");

        auto handler = fallback_model([](const Request&) {
            Response response;
            response.message = assistant_message("fallback");
            return response;
        })([](const Request&) -> Response {
            throw PraxoError("PRIMARY_FAILED", "primary");
        });
        check(handler(Request()).message.content.value_or("") == "fallback", "fallback");

        int invocations = 0;
        auto registry = std::make_shared<ToolRegistry>();
        registry->register_tool(std::make_shared<FuncTool>("echo", "Echo",
            [&](const Json& arguments) { ++invocations; return arguments; }));
        AgentOptions options(std::make_shared<TestModel>(Json::parse(
            R"([{"content":"","toolCalls":[{"id":"c1","name":"echo","arguments":{"text":"hi"}}]},)"
            R"({"content":"done"}])")));
        options.tools = registry;
        auto result = run_agent(options, Session{"s1", {}}, "go");
        check(result.output == "done" && result.steps == 2 && invocations == 1, "agent loop");


        std::vector<Json> final_arguments_invoked;
        auto final_arguments_registry = std::make_shared<ToolRegistry>();
        final_arguments_registry->register_tool(std::make_shared<FuncTool>(
            "echo", "Echo", [&](const Json& arguments) {
                final_arguments_invoked.push_back(arguments);
                return arguments;
            }));
        std::vector<Action> final_arguments_actions;
        AgentOptions final_arguments_options(std::make_shared<TestModel>(Json::parse(
            R"([{"content":"","toolCalls":[{"id":"c1","name":"echo","arguments":{"text":"hi"}}]},)"
            R"({"content":"done"}])")));
        final_arguments_options.tools = final_arguments_registry;
        final_arguments_options.policy = [&](const Action& action) {
            final_arguments_actions.push_back(action);
            return Decision{true, "ok"};
        };
        Middleware mutate_arguments;
        mutate_arguments.before_tool = [](ToolCall call) {
            call.arguments = Json::parse(R"({"text":"mutated"})");
            return call;
        };
        final_arguments_options.middleware.push_back(mutate_arguments);
        (void)run_agent(std::move(final_arguments_options), Session{"s1", {}}, "go");
        check(final_arguments_invoked.size() == 1 &&
              final_arguments_invoked[0].at("text").as_string() == "mutated",
              "cpp final arguments effect");
        check(std::count_if(final_arguments_actions.begin(), final_arguments_actions.end(),
              [](const Action& action) { return action.kind == "tool.invoke"; }) == 2,
              "cpp final arguments reauthorized");

        std::vector<Json> final_name_invoked;
        auto final_name_registry = std::make_shared<ToolRegistry>();
        final_name_registry->register_tool(std::make_shared<FuncTool>(
            "other", "Other", [&](const Json& arguments) {
                final_name_invoked.push_back(arguments);
                return arguments;
            }));
        AgentOptions final_name_options(std::make_shared<TestModel>(Json::parse(
            R"([{"content":"","toolCalls":[{"id":"c1","name":"echo","arguments":{}}]},)"
            R"({"content":"done"}])")));
        final_name_options.tools = final_name_registry;
        final_name_options.allowed_tools = {"echo", "other"};
        Middleware mutate_name;
        mutate_name.before_tool = [](ToolCall call) {
            call.name = "other";
            return call;
        };
        final_name_options.middleware.push_back(mutate_name);
        (void)run_agent(std::move(final_name_options), Session{"s1", {}}, "go");
        check(final_name_invoked.size() == 1, "cpp final name uses final tool");

        AgentOptions denied_name_options(std::make_shared<TestModel>(Json::parse(
            R"([{"content":"","toolCalls":[{"id":"c1","name":"echo","arguments":{}}]},)"
            R"({"content":"done"}])")));
        denied_name_options.tools = final_name_registry;
        denied_name_options.allowed_tools = {"echo"};
        Middleware denied_name;
        denied_name.before_tool = [](ToolCall call) {
            call.name = "other";
            return call;
        };
        denied_name_options.middleware.push_back(denied_name);
        caught = false;
        try {
            (void)run_agent(std::move(denied_name_options), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            caught = error.code() == "AGENT_TOOL_NOT_ALLOWED";
        }
        check(caught, "cpp final name allowlist");

        std::vector<Action> unchanged_actions;
        AgentOptions unchanged_options(std::make_shared<TestModel>(Json::parse(
            R"([{"content":"","toolCalls":[{"id":"c1","name":"echo","arguments":{"text":"hi"}}]},)"
            R"({"content":"done"}])")));
        unchanged_options.tools = final_arguments_registry;
        unchanged_options.policy = [&](const Action& action) {
            unchanged_actions.push_back(action);
            return Decision{true, "ok"};
        };
        unchanged_options.middleware.push_back(Middleware{});
        (void)run_agent(std::move(unchanged_options), Session{"s1", {}}, "go");
        check(std::count_if(unchanged_actions.begin(), unchanged_actions.end(),
              [](const Action& action) { return action.kind == "tool.invoke"; }) == 1,
              "cpp unchanged single authorization");

        int initial_middleware_calls = 0;
        AgentOptions initial_options(std::make_shared<TestModel>(Json::parse(
            R"([{"content":"","toolCalls":[{"id":"c1","name":"echo","arguments":{}}]},)"
            R"({"content":"done"}])")));
        initial_options.tools = final_arguments_registry;
        initial_options.policy = [](const Action& action) {
            return Decision{action.kind != "tool.invoke", "blocked"};
        };
        Middleware initial_middleware;
        initial_middleware.before_tool = [&](ToolCall call) {
            ++initial_middleware_calls;
            return call;
        };
        initial_options.middleware.push_back(initial_middleware);
        caught = false;
        try {
            (void)run_agent(std::move(initial_options), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            caught = error.code() == "AGENT_POLICY_DENIED";
        }
        check(caught && initial_middleware_calls == 0,
              "cpp initial denial prevents middleware");

        std::vector<std::string> startup_calls;
        AgentOptions startup_options(std::make_shared<StaticModel>("done"));
        Middleware startup_first;
        startup_first.before_run = [&](const std::string&, const std::string&) {
            startup_calls.push_back("first.before");
        };
        startup_first.after_run = [&](const RunResult*, const std::string*) {
            startup_calls.push_back("first.after");
        };
        Middleware startup_second;
        startup_second.before_run = [](const std::string&, const std::string&) {
            throw PraxoError("STARTUP_FAILED", "startup failed");
        };
        startup_second.after_run = [&](const RunResult*, const std::string*) {
            startup_calls.push_back("second.after");
        };
        startup_options.middleware = {startup_first, startup_second};
        caught = false;
        try {
            (void)run_agent(std::move(startup_options), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            caught = error.code() == "STARTUP_FAILED";
        }
        check(caught && startup_calls == std::vector<std::string>{
            "first.before", "first.after", "second.after"}, "cpp startup cleanup");

        std::vector<std::string> continue_calls;
        AgentOptions continue_options(std::make_shared<FailingModel>());
        Middleware continue_first;
        continue_first.after_run = [&](const RunResult*, const std::string*) {
            continue_calls.push_back("first.after");
            throw PraxoError("CLEANUP_FAILED", "cleanup failed");
        };
        Middleware continue_second;
        continue_second.after_run = [&](const RunResult*, const std::string*) {
            continue_calls.push_back("second.after");
        };
        continue_options.middleware = {continue_first, continue_second};
        caught = false;
        try {
            (void)run_agent(std::move(continue_options), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            caught = error.code() == "RUN_FAILED";
        }
        check(caught && continue_calls == std::vector<std::string>{
            "first.after", "second.after"}, "cpp after-run continues");

        std::vector<std::string> cleanup_calls;
        AgentOptions cleanup_options(std::make_shared<StaticModel>("done"));
        Middleware cleanup_first;
        cleanup_first.after_run = [&](const RunResult*, const std::string*) {
            cleanup_calls.push_back("first.after");
            throw PraxoError("CLEANUP_FAILED", "cleanup failed");
        };
        Middleware cleanup_second;
        cleanup_second.after_run = [&](const RunResult*, const std::string*) {
            cleanup_calls.push_back("second.after");
        };
        cleanup_options.middleware = {cleanup_first, cleanup_second};
        caught = false;
        try {
            (void)run_agent(std::move(cleanup_options), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            caught = error.code() == "CLEANUP_FAILED";
        }
        check(caught && cleanup_calls == std::vector<std::string>{
            "first.after", "second.after"}, "cpp cleanup fail closed");

        check(parse_sse_stream(
            "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n"
            "data: [DONE]\n\n") == "hi", "cpp sse complete");
        caught = false;
        try {
            (void)parse_sse_stream(
                "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n");
        } catch (const PraxoError& error) {
            caught = error.code() == "MODEL_STREAM";
        }
        check(caught, "cpp sse truncated");
        caught = false;
        try {
            (void)parse_sse_stream("data: {\"choices\"\n\n");
        } catch (const PraxoError& error) {
            caught = error.code() == "MODEL_STREAM";
        }
        check(caught, "cpp sse half packet");

        CallLimit isolated(1, 0);
        isolated.before_model("a");
        caught = false;
        try {
            isolated.before_model("a");
        } catch (const PraxoError& error) {
            caught = error.code() == "AGENT_MODEL_CALL_LIMIT";
        }
        check(caught, "cpp call limit run a");
        isolated.before_model("b");
        check(true, "cpp call limit isolated run");

        bool cancel_flag = false;
        std::vector<std::string> cancel_after;
        AgentOptions cancel_options(std::make_shared<CancelModel>(cancel_flag));
        cancel_options.cancellation = [&] { return cancel_flag; };
        Middleware cancel_middleware;
        cancel_middleware.after_run = [&](const RunResult*, const std::string*) {
            cancel_after.push_back("after");
        };
        cancel_options.middleware.push_back(cancel_middleware);
        RecordingSink cancel_sink;
        cancel_options.events = &cancel_sink;
        caught = false;
        try {
            (void)run_agent(std::move(cancel_options), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            caught = error.code() == "AGENT_CANCELLED";
        }
        check(caught && cancel_after.size() == 1,
              "cpp model cancellation cleanup");
        check(cancel_sink.types == std::vector<std::string>{
            "run.started", "run.failed"}, "cpp model cancellation events");

        bool tool_cancel_flag = false;
        std::vector<std::string> tool_cancel_after;
        Json tool_cancel_steps = Json::parse(
            R"([{"content":"","toolCalls":[{"id":"c1","name":"wait","arguments":{}}]},{"content":"done"}])");
        AgentOptions tool_cancel_options(
            std::make_shared<TestModel>(tool_cancel_steps));
        auto tool_cancel_registry = std::make_shared<ToolRegistry>();
        tool_cancel_registry->register_tool(std::make_shared<FuncTool>(
            "wait", "wait", [&](const Json&) {
                tool_cancel_flag = true;
                return Json("ok");
            }));
        tool_cancel_options.tools = tool_cancel_registry;
        tool_cancel_options.cancellation = [&] { return tool_cancel_flag; };
        Middleware tool_cancel_middleware;
        tool_cancel_middleware.after_run = [&](const RunResult*,
                                               const std::string*) {
            tool_cancel_after.push_back("after");
        };
        tool_cancel_options.middleware.push_back(tool_cancel_middleware);
        RecordingSink tool_cancel_sink;
        tool_cancel_options.events = &tool_cancel_sink;
        caught = false;
        try {
            (void)run_agent(std::move(tool_cancel_options),
                            Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            caught = error.code() == "AGENT_CANCELLED";
        }
        check(caught && tool_cancel_after.size() == 1,
              "cpp tool cancellation cleanup");
        check(tool_cancel_sink.types == std::vector<std::string>{
            "run.started", "tool.call", "run.failed"},
            "cpp tool cancellation events");

        std::vector<std::string> stream_parts;
        AgentOptions stream_options(std::make_shared<StaticModel>("done"));
        stream_options.on_stream = [&](const StreamPart& part) {
            stream_parts.push_back(part.kind);
            if (part.kind == "messages") {
                throw std::runtime_error("stream failed");
            }
        };
        RecordingSink stream_sink;
        stream_options.events = &stream_sink;
        caught = false;
        try {
            (void)run_agent(std::move(stream_options), Session{"s1", {}}, "go");
        } catch (const std::exception& error) {
            caught = std::string(error.what()).find("stream failed") !=
                     std::string::npos;
        }
        check(caught && stream_parts == std::vector<std::string>{
            "values", "messages"}, "cpp stream failure aborts");
        check(stream_sink.types == std::vector<std::string>{
            "run.started", "run.failed"}, "cpp stream failure events");

        std::mutex parallel_mutex;
        std::condition_variable parallel_cv;
        int parallel_started = 0;
        bool parallel_release = false;
        auto parallel_model = std::make_shared<ParallelModel>();
        AgentOptions parallel_options(parallel_model);
        auto parallel_registry = std::make_shared<ToolRegistry>();
        auto tool_a = std::make_shared<FuncTool>("a", "a", [&](const Json&) {
            std::unique_lock<std::mutex> lock(parallel_mutex);
            ++parallel_started;
            parallel_cv.notify_all();
            parallel_cv.wait(lock, [&] { return parallel_release; });
            return Json("a");
        });
        auto tool_b = std::make_shared<FuncTool>("b", "b", [&](const Json&) {
            std::unique_lock<std::mutex> lock(parallel_mutex);
            ++parallel_started;
            parallel_cv.notify_all();
            parallel_cv.wait(lock, [&] { return parallel_release; });
            return Json("b");
        });
        parallel_registry->register_tool(tool_a);
        parallel_registry->register_tool(tool_b);
        parallel_options.tools = parallel_registry;
        parallel_options.max_parallel_tools = 2;
        auto parallel_future = std::async(std::launch::async, [&] {
            return run_agent(std::move(parallel_options), Session{"s1", {}},
                             "go");
        });
        {
            std::unique_lock<std::mutex> lock(parallel_mutex);
            if (!parallel_cv.wait_for(lock, std::chrono::seconds(3), [&] {
                    return parallel_started == 2;
                })) {
                parallel_release = true;
                parallel_cv.notify_all();
                throw std::runtime_error(
                    "cpp parallel tools did not start together");
            }
            parallel_release = true;
            parallel_cv.notify_all();
        }
        RunResult parallel_result = parallel_future.get();
        check(parallel_result.output == "done", "cpp parallel tools result");
        check(parallel_model->order == std::vector<std::string>{"c1", "c2"},
              "cpp parallel tools preserve order");

        int hitl_invocations = 0;
        auto hitl_registry = std::make_shared<ToolRegistry>();
        hitl_registry->register_tool(std::make_shared<FuncTool>(
            "echo", "Echo", [&](const Json& arguments) {
                ++hitl_invocations;
                return arguments;
            }));
        auto hitl_model = [] {
            return std::make_shared<TestModel>(Json::parse(
                R"([{"content":"","toolCalls":[{"id":"c1","name":"echo","arguments":{"value":"original"}}]},)"
                R"({"content":"done"}])"));
        };
        AgentOptions approve_options(hitl_model());
        approve_options.tools = hitl_registry;
        approve_options.interrupt_on = {"echo"};
        approve_options.on_interrupt_decision = [](const Interrupt&) {
            InterruptDecision decision;
            decision.action = InterruptAction::Approve;
            return decision;
        };
        auto approve_result = run_agent(approve_options, Session{"s1", {}}, "go");
        check(approve_result.output == "done" && hitl_invocations == 1,
              "cpp hitl approve");

        hitl_invocations = 0;
        std::vector<Action> hitl_actions;
        AgentOptions edit_options(hitl_model());
        edit_options.tools = hitl_registry;
        edit_options.interrupt_on = {"echo"};
        edit_options.policy = [&](const Action& action) {
            hitl_actions.push_back(action);
            return Decision{true, "ok"};
        };
        edit_options.on_interrupt_decision = [](const Interrupt&) {
            InterruptDecision decision;
            decision.action = InterruptAction::Edit;
            decision.arguments = Json::parse(R"({"value":"edited"})");
            return decision;
        };
        (void)run_agent(std::move(edit_options), Session{"s1", {}}, "go");
        check(hitl_invocations == 1 &&
              std::count_if(hitl_actions.begin(), hitl_actions.end(),
                  [](const Action& action) { return action.kind == "tool.invoke"; }) == 2,
              "cpp hitl edit reauthorizes");

        hitl_invocations = 0;
        AgentOptions reject_options(hitl_model());
        reject_options.tools = hitl_registry;
        reject_options.interrupt_on = {"echo"};
        reject_options.on_interrupt_decision = [](const Interrupt&) {
            InterruptDecision decision;
            decision.action = InterruptAction::Reject;
            decision.reason = "no";
            return decision;
        };
        bool rejected = false;
        try {
            (void)run_agent(std::move(reject_options), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            rejected = error.code() == "AGENT_APPROVAL_DENIED";
        }
        check(rejected && hitl_invocations == 0, "cpp hitl reject");

        AgentOptions unhandled_options(hitl_model());
        unhandled_options.tools = hitl_registry;
        unhandled_options.interrupt_on = {"echo"};
        bool unhandled = false;
        try {
            (void)run_agent(std::move(unhandled_options), Session{"s1", {}}, "go");
        } catch (const PraxoError& error) {
            unhandled = error.code() == "AGENT_INTERRUPT_UNHANDLED";
        }
        check(unhandled && hitl_invocations == 0, "cpp hitl unhandled");

        AgentOptions respond_options(std::make_shared<RespondModel>());
        respond_options.tools = hitl_registry;
        respond_options.interrupt_on = {"echo"};
        respond_options.on_interrupt_decision = [](const Interrupt&) {
            InterruptDecision decision;
            decision.action = InterruptAction::Respond;
            decision.response = "human answer";
            return decision;
        };
        auto respond_result = run_agent(std::move(respond_options), Session{"s1", {}}, "go");
        check(respond_result.output == "\"human answer\"", "cpp hitl respond");

        auto hitl_sink = std::make_shared<RecordingSink>();
        AgentOptions event_options(hitl_model());
        event_options.tools = hitl_registry;
        event_options.events = hitl_sink.get();
        event_options.interrupt_on = {"echo"};
        event_options.on_interrupt_decision = [](const Interrupt&) {
            InterruptDecision decision;
            decision.action = InterruptAction::Approve;
            return decision;
        };
        (void)run_agent(std::move(event_options), Session{"s1", {}}, "go");
        check(std::count(hitl_sink->types.begin(), hitl_sink->types.end(),
                         "tool.interrupt") == 1,
              "cpp hitl event");

        {
            OpenAICompatibleOptions adapter_options;
            adapter_options.base_url = "https://example.test/v1/";
            adapter_options.model = "test-model";
            adapter_options.api_key = "secret";
            std::string captured_url;
            Json captured_payload;
            std::map<std::string, std::string> captured_headers;
            OpenAICompatible adapter(
                adapter_options,
                [&](const std::string& url, const Json& payload,
                    const std::map<std::string, std::string>& headers) {
                    captured_url = url;
                    captured_payload = payload;
                    captured_headers = headers;
                    return Json::parse(
                        R"({"choices":[{"message":{"content":"hello","tool_calls":)"
                        R"([{"id":"call-1","type":"function","function":)"
                        R"({"name":"echo","arguments":"{\"text\":\"hi\"}"}}]},)"
                        R"("finish_reason":"tool_calls"}],)"
                        R"("usage":{"prompt_tokens":3,"completion_tokens":2}})");
                });
            Request adapter_request;
            adapter_request.messages.push_back(text_message(USER, "hello"));
            ToolCall prior;
            prior.id = "prior";
            prior.name = "echo";
            prior.arguments = Json::parse(R"({"a":1})");
            adapter_request.messages.push_back(assistant_message("", {prior}));
            adapter_request.messages.push_back(tool_message(R"({"ok":true})", "prior"));
            ToolSpec adapter_tool;
            adapter_tool.name = "echo";
            adapter_tool.description = "Echo arguments";
            adapter_tool.parameters = Json::parse(R"({"type":"object"})");
            adapter_request.tools.push_back(adapter_tool);
            adapter_request.tool_choice = "auto";
            Response adapter_response = adapter.generate(adapter_request);
            check(captured_url == "https://example.test/v1/chat/completions",
                  "cpp openai endpoint");
            check(captured_headers.at("authorization") == "Bearer secret",
                  "cpp openai authorization");
            check(captured_payload.at("model") == Json("test-model"),
                  "cpp openai model");
            const auto& payload_messages = captured_payload.at("messages").as_array();
            check(payload_messages.size() == 3, "cpp openai message count");
            check(payload_messages[1].at("tool_calls").as_array()[0]
                      .at("function").at("arguments").as_string() == R"({"a":1})",
                  "cpp openai tool arguments encoded");
            check(payload_messages[2].at("tool_call_id") == Json("prior"),
                  "cpp openai tool result id");
            check(captured_payload.at("tools").as_array()[0]
                      .at("function").at("name") == Json("echo"),
                  "cpp openai tool spec");
            check(captured_payload.at("tool_choice") == Json("auto"),
                  "cpp openai tool choice");
            check(adapter_response.message.content.value_or("") == "hello",
                  "cpp openai content");
            check(adapter_response.message.tool_calls.size() == 1 &&
                      adapter_response.message.tool_calls[0].id == "call-1" &&
                      adapter_response.message.tool_calls[0].name == "echo" &&
                      adapter_response.message.tool_calls[0].arguments ==
                          Json::parse(R"({"text":"hi"})"),
                  "cpp openai tool call");
            check(adapter_response.usage.input_tokens == 3 &&
                      adapter_response.usage.output_tokens == 2,
                  "cpp openai usage");
            check(adapter_response.finish_reason.value_or("") == "tool_calls",
                  "cpp openai finish reason");

            OpenAICompatibleOptions invalid_options;
            invalid_options.model = "test-model";
            bool missing_base = false;
            try {
                OpenAICompatible invalid(invalid_options,
                    [](const std::string&, const Json&,
                       const std::map<std::string, std::string>&) {
                        return Json(nullptr);
                    });
                (void)invalid.generate(adapter_request);
            } catch (const PraxoError& error) {
                missing_base = error.code() == "PROVIDER_HTTP";
            }
            check(missing_base, "cpp openai missing base url rejected");

            bool invalid_arguments = false;
            try {
                (void)OpenAICompatible::parse_response(Json::parse(
                    R"({"choices":[{"message":{"content":"","tool_calls":)"
                    R"([{"id":"x","function":{"name":"echo","arguments":"broken"}}]}}]})"));
            } catch (const PraxoError& error) {
                invalid_arguments = error.code() == "PROVIDER_JSON";
            }
            check(invalid_arguments, "cpp openai invalid tool arguments");
        }

        std::cout << "cpp core tests passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << "\n";
        return 1;
    }
}
