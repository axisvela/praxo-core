#pragma once

#include <functional>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include "praxo/models.hpp"

namespace praxo {

class EventSink {
public:
    virtual ~EventSink() = default;
    virtual void emit(const Event& event) = 0;
};

class MultiSink : public EventSink {
public:
    explicit MultiSink(std::vector<EventSink*> sinks) : sinks_(std::move(sinks)) {}
    void emit(const Event& event) override;

private:
    std::vector<EventSink*> sinks_;
};

class FilterSink : public EventSink {
public:
    FilterSink(EventSink* sink, std::function<bool(const Event&)> predicate)
        : sink_(sink), predicate_(std::move(predicate)) {}
    void emit(const Event& event) override;

private:
    EventSink* sink_;
    std::function<bool(const Event&)> predicate_;
};

class MemoryStore {
public:
    MemoryRecord put(const std::string& session_id, MemoryRecord record);
    std::vector<MemoryRecord> search(const std::string& session_id,
                                     const std::string& query, int limit) const;

private:
    std::map<std::string, std::vector<MemoryRecord>> records_;
    int sequence_ = 0;
};

class CheckpointAllowlist {
public:
    void register_type(const std::string& type);
    std::string marshal(const std::string& type, const Json& value) const;
    Json unmarshal(const std::string& data) const;

private:
    std::set<std::string> registered_;
};

class PathChecker {
public:
    explicit PathChecker(std::vector<PathGrant> grants);
    Decision check(const std::string& target, const std::string& need) const;
    bool allowed(const std::string& target, const std::string& need) const;

private:
    std::vector<PathGrant> grants_;
};

struct ContextBudget {
    int max_tokens = 0;
    int keep_recent = 0;

    std::pair<std::vector<Message>, bool> compact(const std::vector<Message>& messages) const;
};

int estimate_tokens(const std::vector<Message>& messages);
std::string truncate_to_tokens(const std::string& value, int tokens);

}  // namespace praxo
