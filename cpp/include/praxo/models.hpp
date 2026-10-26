#pragma once

#include <optional>
#include <string>
#include <vector>

#include "praxo/json.hpp"

namespace praxo {

inline constexpr const char* SYSTEM = "system";
inline constexpr const char* USER = "user";
inline constexpr const char* ASSISTANT = "assistant";
inline constexpr const char* TOOL = "tool";

inline const std::vector<std::string>& stream_kinds() {
    static const std::vector<std::string> kinds = {
        "values", "updates", "messages", "tasks", "debug", "checkpoint",
    };
    return kinds;
}

struct ContentBlock {
    std::string type = "text";
    std::optional<std::string> text;
    std::optional<std::string> image_url;
    std::optional<std::string> data;

    Json wire() const {
        Json out = Json::object();
        out["type"] = type;
        if (text) out["text"] = *text;
        if (image_url) out["image_url"] = *image_url;
        if (data) out["data"] = *data;
        return out;
    }
};

struct ToolCall {
    std::string id;
    std::string name;
    Json arguments = Json::object();

    Json wire() const {
        Json out = Json::object();
        out["id"] = id;
        out["name"] = name;
        out["arguments"] = arguments;
        return out;
    }
};

struct Message {
    std::string role;
    std::optional<std::string> content;
    std::vector<ContentBlock> content_blocks;
    std::vector<ToolCall> tool_calls;
    std::optional<std::string> tool_id;
};

struct ToolSpec {
    std::string name;
    std::string description;
    Json parameters = Json(nullptr);
    std::optional<std::string> risk;
};

struct Usage {
    int input_tokens = 0;
    int output_tokens = 0;
    int cached_tokens = 0;

    Usage plus(const Usage& other) const {
        return {input_tokens + other.input_tokens,
                output_tokens + other.output_tokens,
                cached_tokens + other.cached_tokens};
    }
};

struct Request {
    std::vector<Message> messages;
    std::vector<ToolSpec> tools;
    std::optional<std::string> tool_choice;
    Json response_format = Json(nullptr);
    double temperature = 0;
};

struct Response {
    Message message;
    Usage usage;
    std::optional<std::string> finish_reason;
};

struct Session {
    std::string id;
    std::vector<Message> messages;
};

struct RunResult {
    std::string run_id;
    std::string output;
    int steps = 0;
    Usage usage;
};

struct MemoryRecord {
    std::string id;
    std::string frame;
    std::string content;
    std::optional<std::string> created_at;
};

struct PathGrant {
    std::string root;
    std::string access = "read";
};

struct Action {
    std::string kind;
    std::string session_id;
    std::optional<std::string> tool_name;
    Json arguments = Json(nullptr);
};

struct Decision {
    bool allowed = false;
    std::string reason;
};

struct Event {
    std::string type;
    std::string session_id;
    std::optional<std::string> run_id;
    Json data = Json(nullptr);
};

inline Message text_message(const std::string& role, const std::string& content) {
    Message message;
    message.role = role;
    message.content = content;
    return message;
}

inline Message assistant_message(const std::string& content,
                                 std::vector<ToolCall> tool_calls = {}) {
    Message message;
    message.role = ASSISTANT;
    message.content = content;
    message.tool_calls = std::move(tool_calls);
    return message;
}

inline Message tool_message(const std::string& content, const std::string& tool_id) {
    Message message;
    message.role = TOOL;
    message.content = content;
    message.tool_id = tool_id;
    return message;
}

inline Json message_wire(const Message& message) {
    Json out = Json::object();
    out["role"] = message.role;
    if (message.content) out["content"] = *message.content;
    if (!message.content_blocks.empty()) {
        Json blocks = Json::array();
        for (const auto& block : message.content_blocks) blocks.push_back(block.wire());
        out["contentBlocks"] = blocks;
    }
    if (!message.tool_calls.empty()) {
        Json calls = Json::array();
        for (const auto& call : message.tool_calls) calls.push_back(call.wire());
        out["toolCalls"] = calls;
    }
    if (message.tool_id) out["toolId"] = *message.tool_id;
    return out;
}

inline Json event_wire(const Event& event) {
    Json out = Json::object();
    out["type"] = event.type;
    out["sessionId"] = event.session_id;
    if (event.run_id) out["runId"] = *event.run_id;
    if (!event.data.is_null()) out["data"] = event.data;
    return out;
}

}  // namespace praxo
