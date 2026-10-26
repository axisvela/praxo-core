#include <algorithm>
#include <cctype>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <random>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "praxo/agent.hpp"
#include "praxo/errors.hpp"
#include "praxo/jsonschema.hpp"
#include "praxo/middleware.hpp"
#include "praxo/models.hpp"
#include "praxo/plugin.hpp"
#include "praxo/runtime.hpp"
#include "praxo/toolcall.hpp"

namespace {

using namespace praxo;
namespace fs = std::filesystem;

std::string read_file(const fs::path& path) {
    std::ifstream stream(path, std::ios::binary);
    if (!stream) throw std::runtime_error("cannot read " + path.string());
    std::ostringstream out;
    out << stream.rdbuf();
    return out.str();
}

fs::path repo_root() {
    fs::path current = fs::current_path();
    while (true) {
        if (fs::exists(current / "spec" / "SPEC_VERSION")) return current;
        if (!current.has_parent_path() || current.parent_path() == current) {
            throw std::runtime_error("cannot find repository root");
        }
        current = current.parent_path();
    }
}

std::string jstring(const Json& node, const std::string& key,
                    const std::string& fallback = "") {
    return node.contains(key) && node.at(key).is_string() ? node.at(key).as_string() : fallback;
}

int jint(const Json& node, const std::string& key, int fallback = 0) {
    return node.contains(key) && node.at(key).is_number()
        ? static_cast<int>(node.at(key).as_number()) : fallback;
}

bool jbool(const Json& node, const std::string& key, bool fallback = false) {
    return node.contains(key) && node.at(key).is_bool() ? node.at(key).as_bool() : fallback;
}

Json jarray(const Json& node, const std::string& key) {
    return node.contains(key) && node.at(key).is_array() ? node.at(key) : Json::array();
}

Json jget(const Json& node, const std::string& key) {
    return node.contains(key) ? node.at(key) : Json(nullptr);
}

std::string error_code(const std::exception& error) {
    if (auto* praxo = dynamic_cast<const PraxoError*>(&error)) return praxo->code();
    return "";
}

void check(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

class RecordingSink : public EventSink {
public:
    void emit(const Event& event) override { types.push_back(event.type); }
    std::vector<std::string> types;
};

class ScriptedModel : public Model {
public:
    explicit ScriptedModel(Json steps) : steps_(std::move(steps)) {}
    Response generate(const Request& request) override {
        (void)request;
        if (next_ >= steps_.as_array().size()) {
            throw std::runtime_error("script exhausted");
        }
        const Json& step = steps_.as_array()[next_++];
        Response response;
        response.message.role = ASSISTANT;
        response.message.content = jstring(step, "content");
        response.usage.input_tokens = jint(step, "inputTokens");
        response.usage.output_tokens = jint(step, "outputTokens");
        for (const auto& item : jarray(step, "toolCalls").as_array()) {
            ToolCall call;
            call.id = jstring(item, "id");
            call.name = jstring(item, "name");
            call.arguments = jget(item, "arguments");
            response.message.tool_calls.push_back(call);
        }
        return response;
    }

private:
    Json steps_;
    std::size_t next_ = 0;
};

class EchoTool : public Tool {
public:
    EchoTool(std::string name, std::string description, int* calls)
        : name_(std::move(name)), description_(std::move(description)), calls_(calls) {}
    std::string name() const override { return name_; }
    std::string description() const override { return description_; }
    Json invoke(const Json& arguments) override {
        ++*calls_;
        return arguments;
    }

private:
    std::string name_;
    std::string description_;
    int* calls_;
};

void run_toolcall(const Json& input, const Json& expect) {
    std::string operation = jstring(input, "operation");
    std::string content = jstring(input, "content");
    if (operation == "strip") {
        check(strip_markup(content) == jstring(expect, "text"), "strip mismatch");
        return;
    }
    auto call = parse_toolcall(content);
    if (jbool(expect, "nil")) {
        check(!call.has_value(), "expected nil");
        return;
    }
    check(call.has_value(), "expected a tool call");
    check(call->name == jstring(expect, "name"), "name: got " + call->name);
    check(call->input == jget(expect, "input"), "input mismatch");
}

void run_jsonschema(const Json& input, const Json& expect) {
    auto errors = validate(jget(input, "schema"), jget(input, "data"));
    std::vector<std::string> paths;
    for (const auto& error : errors) paths.push_back(error.path);
    std::sort(paths.begin(), paths.end());
    std::vector<std::string> expected;
    for (const auto& item : jarray(expect, "errorPaths").as_array()) {
        if (item.is_string()) expected.push_back(item.as_string());
    }
    std::sort(expected.begin(), expected.end());
    check(errors.empty() == jbool(expect, "valid"), "valid mismatch");
    check(paths == expected, "errorPaths mismatch");
}

void run_plugin(const Json& input, const Json& expect) {
    std::string raw = jstring(input, "raw");
    if (raw.empty()) raw = jget(input, "manifest").dump();
    std::optional<PluginManifest> manifest;
    try {
        manifest = parse_manifest(raw);
    } catch (...) {
    }
    check(manifest.has_value() == jbool(expect, "valid"), "valid mismatch");
    if (!manifest) return;
    if (expect.contains("id")) check(manifest->id == jstring(expect, "id"), "id mismatch");
    if (expect.contains("kind")) check(manifest->kind == jstring(expect, "kind"), "kind mismatch");
}

void run_memory(const Json& input, const Json& expect) {
    MemoryStore store;
    for (const auto& put : jarray(input, "puts").as_array()) {
        const Json& record = jget(put, "record");
        MemoryRecord value;
        value.id = jstring(record, "id");
        value.frame = jstring(record, "frame");
        value.content = jstring(record, "content");
        if (record.contains("createdAt") && record.at("createdAt").is_string()) {
            value.created_at = record.at("createdAt").as_string();
        }
        store.put(jstring(put, "session"), value);
    }
    auto records = store.search(jstring(input, "session"), jstring(input, "query"),
                                jint(input, "limit"));
    Json ids = Json(nullptr);
    Json contents = Json(nullptr);
    if (!records.empty()) {
        ids = Json::array();
        contents = Json::array();
        for (const auto& record : records) {
            ids.push_back(record.id);
            contents.push_back(record.content);
        }
    }
    check(ids == jget(expect, "ids"), "ids mismatch");
    check(contents == jget(expect, "contents"), "contents mismatch");
}

Json types_json(const std::vector<std::string>& types) {
    Json out = Json::array();
    for (const auto& type : types) out.push_back(type);
    return out;
}

void run_event(const Json& input, const Json& expect) {
    std::vector<Event> events;
    for (const auto& item : jarray(input, "events").as_array()) {
        if (!item.is_string()) continue;
        Event event;
        event.type = item.as_string();
        event.session_id = "s1";
        events.push_back(event);
    }
    if (jstring(input, "sink", "filter") == "multi") {
        int count = std::max(1, jint(input, "sinkCount", 1));
        std::vector<RecordingSink> sinks(static_cast<std::size_t>(count));
        std::vector<EventSink*> pointers;
        for (auto& sink : sinks) pointers.push_back(&sink);
        MultiSink multi(pointers);
        for (const auto& event : events) multi.emit(event);
        Json per_sink = Json::array();
        for (const auto& sink : sinks) per_sink.push_back(types_json(sink.types));
        check(per_sink == jget(expect, "perSink"), "perSink mismatch");
        return;
    }
    RecordingSink sink;
    std::set<std::string> allowed;
    bool has_predicate = input.contains("predicateTypes") &&
                         input.at("predicateTypes").is_array();
    if (has_predicate) {
        for (const auto& item : input.at("predicateTypes").as_array()) {
            if (item.is_string()) allowed.insert(item.as_string());
        }
    }
    FilterSink filter(&sink, [&](const Event& event) {
        return !has_predicate || allowed.count(event.type) > 0;
    });
    for (const auto& event : events) filter.emit(event);
    Json delivered = sink.types.empty() ? Json(nullptr) : types_json(sink.types);
    check(delivered == jget(expect, "delivered"), "delivered mismatch");
}

void run_stream(const Json& expect) {
    Json kinds = Json::array();
    for (const auto& kind : stream_kinds()) kinds.push_back(kind);
    check(kinds == jget(expect, "kinds"), "kinds mismatch");
}

void run_checkpoint(const Json& input, const Json& expect) {
    CheckpointAllowlist allowlist;
    for (const auto& item : jarray(input, "registered").as_array()) {
        if (item.is_string()) allowlist.register_type(item.as_string());
    }
    std::string operation = jstring(input, "operation", "roundtrip");
    std::string type = jstring(input, "type");
    Json value = jget(input, "value");
    if (operation == "roundtrip") {
        std::string data = allowlist.marshal(type, value);
        check(allowlist.unmarshal(data) == jget(expect, "value"), "value mismatch");
        return;
    }
    std::string code;
    try {
        if (operation == "marshal") allowlist.marshal(type, value);
        else if (operation == "unmarshal") {
            Json envelope = Json::object();
            envelope["type"] = type;
            envelope["data"] = value;
            allowlist.unmarshal(envelope.dump());
        } else throw PraxoError("CHECKPOINT_ERROR", "unknown operation");
    } catch (const std::exception& error) {
        code = error_code(error);
    }
    check(code == jstring(expect, "errorCode"), "errorCode: got " + code);
}

void run_policy(const Json& input, const Json& expect) {
    auto base = fs::temp_directory_path() /
        ("praxo-policy-" + std::to_string(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count()));
    fs::create_directories(base);
    try {
        for (const auto& dir : jarray(input, "makeDirs").as_array()) {
            if (dir.is_string()) fs::create_directories(base / dir.as_string());
        }
        std::vector<PathGrant> grants;
        for (const auto& item : jarray(input, "grants").as_array()) {
            auto root = base / jstring(item, "root");
            fs::create_directories(root);
            grants.push_back({root.string(), jstring(item, "access", "read")});
        }
        PathChecker checker(grants);
        auto target = base / jstring(input, "target");
        std::string need = jstring(input, "need", "read");
        if (jbool(expect, "error")) {
            bool caught = false;
            try { checker.check(target.string(), need); } catch (...) { caught = true; }
            check(caught, "expected a policy error");
        } else {
            check(checker.check(target.string(), need).allowed == jbool(expect, "allowed"),
                  "allowed mismatch");
        }
    } catch (...) {
        fs::remove_all(base);
        throw;
    }
    fs::remove_all(base);
}

void run_context(const Json& input, const Json& expect) {
    std::vector<Message> messages;
    for (const auto& item : jarray(input, "messages").as_array()) {
        messages.push_back(text_message(jstring(item, "role"), jstring(item, "content")));
    }
    if (jstring(input, "operation") == "estimate") {
        check(estimate_tokens(messages) == jint(expect, "tokens"), "tokens mismatch");
        return;
    }
    Json budget = jget(input, "budget");
    ContextBudget context{jint(budget, "maxTokens"), jint(budget, "keepRecent")};
    auto [output, ok] = context.compact(messages);
    check(ok == jbool(expect, "ok"), "ok mismatch");
    if (!ok) return;
    check(estimate_tokens(output) == jint(expect, "tokens"), "tokens mismatch");
    Json wire = Json::array();
    for (const auto& message : output) wire.push_back(message_wire(message));
    check(wire == jget(expect, "messages"), "messages mismatch");
}

void run_middleware(const Json& input, const Json& expect) {
    std::string operation = jstring(input, "operation");
    if (operation == "pii") {
        check(PiiRedactor().redact(jstring(input, "text")) == jstring(expect, "text"),
              "text mismatch");
    } else if (operation == "pii-value") {
        check(PiiRedactor().redact_value(jget(input, "value")) == jget(expect, "value"),
              "value mismatch");
    } else if (operation == "structured") {
        std::optional<std::string> repair;
        if (input.contains("repairOutput") && input.at("repairOutput").is_string()) {
            std::string value = input.at("repairOutput").as_string();
            repair = value;
        }
        StructuredOutput output(jget(input, "schema"), jint(input, "maxRepairs"),
            repair ? std::function<std::optional<std::string>(const std::string&)>(
                         [repair](const std::string&) { return repair; })
                   : std::function<std::optional<std::string>(const std::string&)>());
        auto [text, code] = output.apply(jstring(input, "output"));
        if (jbool(expect, "ok")) {
            check(text.has_value() && *text == jstring(expect, "output"), "output mismatch");
        } else {
            check(code.has_value() && *code == jstring(expect, "errorCode"), "errorCode mismatch");
        }
    } else if (operation == "call-limit") {
        CallLimit limit(jint(input, "modelLimit"), jint(input, "toolLimit"));
        Json outcomes = Json::array();
        for (const auto& item : jarray(input, "calls").as_array()) {
            std::string code = "ok";
            try {
                if (item.is_string() && item.as_string() == "model") limit.before_model();
                else limit.before_tool();
            } catch (const std::exception& error) {
                code = error_code(error);
            }
            outcomes.push_back(code);
        }
        check(outcomes == jget(expect, "outcomes"), "outcomes mismatch");
    } else if (operation == "tool-selection") {
        std::vector<std::string> selected;
        for (const auto& item : jarray(input, "selected").as_array()) {
            if (item.is_string()) selected.push_back(item.as_string());
        }
        ToolSelection selection(selected);
        std::vector<ToolSpec> tools;
        for (const auto& item : jarray(input, "tools").as_array()) {
            if (item.is_string()) {
                ToolSpec spec;
                spec.name = item.as_string();
                tools.push_back(spec);
            }
        }
        Json advertised = Json::array();
        for (const auto& tool : selection.filter(tools)) advertised.push_back(tool.name);
        check(advertised == jget(expect, "advertised"), "advertised mismatch");
        std::string reject = "ok";
        try { selection.reject(jstring(input, "requested")); }
        catch (const std::exception& error) { reject = error_code(error); }
        check(reject == jstring(expect, "reject"), "reject mismatch");
    } else if (operation == "fallback") {
        std::string content = jstring(input, "fallbackContent");
        auto handler = fallback_model([content](const Request&) {
            Response response;
            response.message = assistant_message(content);
            return response;
        })([](const Request&) -> Response {
            throw PraxoError("PRIMARY_FAILED", "primary");
        });
        check(handler(Request()).message.content.value_or("") == content, "output mismatch");
    } else {
        throw std::runtime_error("unknown middleware operation");
    }
}

void run_agent_loop(const Json& input, const Json& expect) {
    int invocations = 0;
    auto registry = std::make_shared<ToolRegistry>();
    for (const auto& item : jarray(input, "tools").as_array()) {
        registry->register_tool(std::make_shared<EchoTool>(
            jstring(item, "name"), jstring(item, "description"), &invocations));
    }
    RecordingSink sink;
    AgentOptions options(std::make_shared<ScriptedModel>(jget(input, "script")));
    options.tools = registry;
    options.events = &sink;
    options.max_steps = jint(input, "maxSteps");
    options.max_tokens = jint(input, "maxTokens");
    std::optional<RunResult> result;
    bool threw = false;
    std::string failure_code;
    std::string failure_message;
    try {
        result = run_agent(options, Session{"s1", {}}, jstring(input, "prompt"));
    } catch (const std::exception& error) {
        threw = true;
        failure_code = error_code(error);
        failure_message = error.what();
    }
    if (jbool(expect, "error")) {
        check(threw, "unexpected success");
        if (expect.contains("errorCode")) {
            check(failure_code == jstring(expect, "errorCode"), "errorCode mismatch");
        }
    } else {
        check(!threw, "unexpected failure: " + failure_message);
        check(result.has_value(), "missing result");
        check(result->output == jstring(expect, "output"), "output mismatch");
        check(result->steps == jint(expect, "steps"), "steps mismatch");
    }
    check(invocations == jint(expect, "toolInvocations"), "tool invocations mismatch");
    Json events = sink.types.empty() ? Json(nullptr) : types_json(sink.types);
    check(events == jget(expect, "events"), "events mismatch");
}

void run_vector(const std::string& group, const Json& vector) {
    const Json& input = jget(vector, "input");
    const Json& expect = jget(vector, "expect");
    if (group == "toolcall") run_toolcall(input, expect);
    else if (group == "jsonschema") run_jsonschema(input, expect);
    else if (group == "plugin") run_plugin(input, expect);
    else if (group == "memory") run_memory(input, expect);
    else if (group == "event") run_event(input, expect);
    else if (group == "stream") run_stream(expect);
    else if (group == "checkpoint") run_checkpoint(input, expect);
    else if (group == "policy") run_policy(input, expect);
    else if (group == "context") run_context(input, expect);
    else if (group == "middleware") run_middleware(input, expect);
    else if (group == "agent-loop") run_agent_loop(input, expect);
    else throw std::runtime_error("no runner for group " + group);
}

}  // namespace

int run_conformance() {
    try {
        auto root = repo_root();
        std::string version = read_file(root / "spec" / "SPEC_VERSION");
        while (!version.empty() && std::isspace(static_cast<unsigned char>(version.back()))) {
            version.pop_back();
        }
        std::vector<fs::path> files;
        for (const auto& entry : fs::directory_iterator(root / "spec" / "vectors")) {
            if (entry.path().extension() == ".json") files.push_back(entry.path());
        }
        std::sort(files.begin(), files.end());
        std::vector<std::string> failures;
        std::map<std::string, std::string> seen;
        for (const auto& path : files) {
            std::string name = path.stem().string();
            Json file;
            try {
                file = Json::parse(read_file(path));
            } catch (const std::exception& error) {
                failures.push_back(name + ": invalid vector file: " + error.what());
                continue;
            }
            std::string group = jstring(file, "group");
            if (jstring(file, "specVersion") != version) {
                failures.push_back(name + ": specVersion mismatch");
            }
            if (name != group) failures.push_back(name + ": group mismatch");
            for (const auto& vector : jarray(file, "vectors").as_array()) {
                std::string id = jstring(vector, "id");
                if (seen.count(id)) {
                    failures.push_back(group + "/" + id + ": duplicate id with " + seen[id]);
                }
                seen[id] = group;
                try {
                    run_vector(group, vector);
                } catch (const std::exception& error) {
                    failures.push_back(group + "/" + id + ": " + error.what());
                }
            }
        }
        if (failures.empty()) {
            std::cout << "all spec vectors passed\n";
            return 0;
        }
        for (const auto& failure : failures) std::cerr << failure << "\n";
        return 1;
    } catch (const std::exception& error) {
        std::cerr << error.what() << "\n";
        return 1;
    }
}
