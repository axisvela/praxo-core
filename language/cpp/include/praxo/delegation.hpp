#pragma once

#include <cstdio>
#include <ctime>
#include <functional>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include "praxo/errors.hpp"
#include "praxo/json.hpp"
#include "praxo/models.hpp"

namespace praxo {

struct SubagentRequest {
    std::string parent_session_id;
    std::string agent_id;
    std::string prompt;
    std::map<std::string, Json> context;
    std::string mode = "isolated";
    std::vector<Message> history;
};

struct SubagentResult {
    std::string task_id;
    std::string agent_id;
    std::string output;
    std::optional<Usage> usage;
};

struct SubagentTask {
    std::string id;
    std::string parent_session_id;
    std::string agent_id;
    std::string mode;
    std::string status;
    std::string output;
    std::string error;
    std::string created_at;
    std::string updated_at;
};

using SubagentRunner = std::function<SubagentResult(const SubagentRequest&)>;

inline std::string subagent_timestamp() {
    const std::time_t now = std::time(nullptr);
    std::tm value{};
#ifdef _WIN32
    gmtime_s(&value, &now);
#else
    gmtime_r(&now, &value);
#endif
    char buffer[32];
    std::snprintf(buffer, sizeof(buffer), "%04d-%02d-%02dT%02d:%02d:%02dZ",
        value.tm_year + 1900, value.tm_mon + 1, value.tm_mday,
        value.tm_hour, value.tm_min, value.tm_sec);
    return buffer;
}

inline SubagentTask subagent_run(const SubagentRunner& runner,
                                 const SubagentRequest& request) {
    if (!runner) {
        throw PraxoError("SUBAGENT_INVALID", "agent: subagent runner is required");
    }
    if (request.parent_session_id.empty() || request.agent_id.empty()) {
        throw PraxoError(
            "SUBAGENT_INVALID",
            "agent: subagent parent session and agent id are required");
    }
    SubagentTask task;
    task.id = "subagent-" + std::to_string(std::time(nullptr));
    task.parent_session_id = request.parent_session_id;
    task.agent_id = request.agent_id;
    task.mode = request.mode == "fork" ? "fork" : "isolated";
    task.status = "running";
    task.created_at = subagent_timestamp();
    task.updated_at = task.created_at;
    try {
        const SubagentResult result = runner(request);
        task.status = "completed";
        task.output = result.output;
    } catch (const std::exception& error) {
        task.status = "failed";
        task.error = error.what();
    }
    task.updated_at = subagent_timestamp();
    return task;
}

}  // namespace praxo
