#include "praxo/runtime.hpp"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <ctime>
#include <filesystem>
#include <sstream>

#include "praxo/errors.hpp"

namespace praxo {

void MultiSink::emit(const Event& event) {
    for (auto* sink : sinks_) sink->emit(event);
}

void FilterSink::emit(const Event& event) {
    if (predicate_(event)) sink_->emit(event);
}

MemoryRecord MemoryStore::put(const std::string& session_id, MemoryRecord record) {
    if (record.id.empty()) {
        auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();
        record.id = "mem-" + std::to_string(millis) + "-" + std::to_string(sequence_++);
    }
    if (!record.created_at) {
        std::time_t now = std::time(nullptr);
        std::tm tm{};
#ifdef _WIN32
        gmtime_s(&tm, &now);
#else
        gmtime_r(&now, &tm);
#endif
        char buffer[32];
        std::strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &tm);
        record.created_at = buffer;
    }
    records_[session_id].push_back(record);
    return record;
}

std::vector<MemoryRecord> MemoryStore::search(const std::string& session_id,
                                              const std::string& query, int limit) const {
    std::string needle = query;
    std::transform(needle.begin(), needle.end(), needle.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    needle.erase(0, needle.find_first_not_of(" \t\r\n"));
    needle.erase(needle.find_last_not_of(" \t\r\n") + 1);

    std::vector<MemoryRecord> matches;
    auto it = records_.find(session_id);
    if (it != records_.end()) {
        for (const auto& record : it->second) {
            std::string content = record.content;
            std::transform(content.begin(), content.end(), content.begin(),
                           [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            if (needle.empty() || content.find(needle) != std::string::npos) {
                matches.push_back(record);
            }
        }
    }
    std::sort(matches.begin(), matches.end(), [](const MemoryRecord& a, const MemoryRecord& b) {
        return (a.created_at.value_or("")) > (b.created_at.value_or(""));
    });
    if (limit > 0 && matches.size() > static_cast<std::size_t>(limit)) {
        matches.resize(static_cast<std::size_t>(limit));
    }
    return matches;
}

void CheckpointAllowlist::register_type(const std::string& type) {
    if (type.empty()) throw PraxoError("CHECKPOINT_ERROR", "checkpoint: type is required");
    registered_.insert(type);
}

std::string CheckpointAllowlist::marshal(const std::string& type, const Json& value) const {
    if (registered_.find(type) == registered_.end()) {
        throw PraxoError("CHECKPOINT_TYPE_NOT_ALLOWED",
                         "checkpoint: payload type not allowed: " + type);
    }
    Json envelope = Json::object();
    envelope["type"] = type;
    envelope["data"] = value;
    return envelope.dump();
}

Json CheckpointAllowlist::unmarshal(const std::string& data) const {
    Json envelope = Json::parse(data);
    if (!envelope.is_object()) {
        throw PraxoError("CHECKPOINT_ERROR", "checkpoint: envelope must be an object");
    }
    std::string type = envelope.contains("type") && envelope.at("type").is_string()
        ? envelope.at("type").as_string() : "";
    if (registered_.find(type) == registered_.end()) {
        throw PraxoError("CHECKPOINT_TYPE_NOT_ALLOWED",
                         "checkpoint: payload type not allowed: " + type);
    }
    return envelope.at("data");
}

namespace {

std::filesystem::path resolve_path(const std::string& value) {
    std::error_code ec;
    auto absolute = std::filesystem::absolute(std::filesystem::path(value), ec);
    if (ec) absolute = std::filesystem::path(value);
    auto canonical = std::filesystem::weakly_canonical(absolute, ec);
    return ec ? absolute.lexically_normal() : canonical;
}

std::string normalized(const std::filesystem::path& path) {
    std::string value = path.string();
#ifdef _WIN32
    std::transform(value.begin(), value.end(), value.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
#endif
    while (!value.empty() && (value.back() == '/' || value.back() == '\\')) value.pop_back();
    return value;
}

bool within(const std::filesystem::path& root, const std::filesystem::path& target) {
    std::string root_value = normalized(root);
    std::string target_value = normalized(target);
    if (target_value == root_value) return true;
    char separator = std::filesystem::path::preferred_separator;
    return target_value.rfind(root_value + separator, 0) == 0;
}

bool allows(const std::string& grant, const std::string& need) {
    if (need == "read") return grant == "read" || grant == "readwrite";
    if (need == "write") return grant == "write" || grant == "readwrite";
    return grant == "readwrite";
}

}  // namespace

PathChecker::PathChecker(std::vector<PathGrant> grants) : grants_(std::move(grants)) {
    for (auto& grant : grants_) grant.root = resolve_path(grant.root).string();
}

Decision PathChecker::check(const std::string& target, const std::string& need) const {
    if (need != "read" && need != "write" && need != "readwrite") {
        throw PraxoError("POLICY_ERROR", "policy: invalid access");
    }
    if (grants_.empty()) return {false, "no allowed roots"};
    auto resolved = resolve_path(target);
    bool matched = false;
    for (const auto& grant : grants_) {
        if (!within(grant.root, resolved)) continue;
        matched = true;
        if (allows(grant.access, need)) {
            return {true, "path within " + grant.root};
        }
    }
    return {false, matched ? "insufficient grant" : "outside roots"};
}

bool PathChecker::allowed(const std::string& target, const std::string& need) const {
    try {
        return check(target, need).allowed;
    } catch (...) {
        return false;
    }
}

int estimate_tokens(const std::vector<Message>& messages) {
    int total = 0;
    for (const auto& message : messages) {
        total += 4 + static_cast<int>((message.content ? message.content->size() : 0) / 4);
        total += static_cast<int>((message.tool_id ? message.tool_id->size() : 0) / 4);
        for (const auto& block : message.content_blocks) {
            total += 4 + static_cast<int>((block.text ? block.text->size() : 0) / 4);
            total += static_cast<int>((block.image_url ? block.image_url->size() : 0) / 4);
            total += static_cast<int>((block.data ? block.data->size() : 0) / 4);
        }
        for (const auto& call : message.tool_calls) {
            total += 4 + static_cast<int>(call.name.size() / 4);
            total += static_cast<int>(call.arguments.dump().size() / 4);
        }
    }
    return total;
}

std::string truncate_to_tokens(const std::string& value, int tokens) {
    if (tokens <= 0) return "";
    std::size_t limit = static_cast<std::size_t>(tokens) * 4;
    if (value.size() <= limit) return value;
    if (limit <= 16) return value.substr(0, limit);
    return value.substr(0, limit - 16) + "\n[truncated]";
}

std::pair<std::vector<Message>, bool> ContextBudget::compact(
    const std::vector<Message>& messages) const {
    if (max_tokens <= 0 || estimate_tokens(messages) <= max_tokens) {
        return {messages, true};
    }
    std::vector<Message> system;
    std::vector<Message> rest;
    for (const auto& message : messages) {
        if (message.role == SYSTEM) {
            if (message.content && message.content->rfind("[context compacted:", 0) == 0) {
                continue;
            }
            system.push_back(message);
        } else {
            rest.push_back(message);
        }
    }
    if (estimate_tokens(system) > max_tokens) {
        if (system.empty()) return {{}, false};
        Message first = system.front();
        first.content = truncate_to_tokens(first.content.value_or(""), max_tokens - 4);
        system = {first};
        if (estimate_tokens(system) > max_tokens) return {{}, false};
    }
    int keep = keep_recent > 0 ? keep_recent : 4;
    int start = static_cast<int>(rest.size()) - keep;
    if (start < 0) start = 0;
    while (start > 0 && start < static_cast<int>(rest.size()) &&
           rest[static_cast<std::size_t>(start)].role == TOOL) {
        --start;
    }
    Message marker = text_message(SYSTEM,
        "[context compacted: " + std::to_string(start) + " older messages omitted]");
    std::vector<Message> kept(rest.begin() + start, rest.end());
    auto build = [&]() {
        std::vector<Message> output = system;
        if (start > 0) output.push_back(marker);
        output.insert(output.end(), kept.begin(), kept.end());
        return output;
    };
    auto output = build();
    while (estimate_tokens(output) > max_tokens && kept.size() > 1) {
        if (kept[1].role == TOOL) break;
        kept.erase(kept.begin());
        output = build();
    }
    return {output, estimate_tokens(output) <= max_tokens};
}

}  // namespace praxo
