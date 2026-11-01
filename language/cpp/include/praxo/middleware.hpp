#pragma once

#include <functional>
#include <map>
#include <optional>
#include <regex>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include "praxo/models.hpp"

namespace praxo {

using ModelHandler = std::function<Response(const Request&)>;
using ModelMiddleware = std::function<ModelHandler(ModelHandler)>;

class PiiRedactor {
public:
    PiiRedactor();
    std::string redact(const std::string& text) const;
    Json redact_value(const Json& value) const;

private:
    std::vector<std::pair<std::regex, std::string>> rules_;
};

class StructuredOutput {
public:
    StructuredOutput(Json schema, int max_repairs = 0,
                     std::function<std::optional<std::string>(const std::string&)> repairer = {});

    std::pair<std::optional<std::string>, std::optional<std::string>> apply(
        const std::string& text) const;

private:
    Json schema_;
    int max_repairs_;
    std::function<std::optional<std::string>(const std::string&)> repairer_;
};

class CallLimit {
public:
    CallLimit(int model_limit, int tool_limit);
    void before_run(const std::string& run_id);
    void before_model(const std::string& run_id = "");
    void before_tool(const std::string& run_id = "");

private:
    int model_limit_;
    int tool_limit_;
    std::map<std::string, std::pair<int, int>> runs_;
};

class ToolSelection {
public:
    explicit ToolSelection(std::vector<std::string> selected);
    std::vector<ToolSpec> filter(const std::vector<ToolSpec>& tools) const;
    void reject(const std::string& name) const;

private:
    std::set<std::string> selected_;
};

ModelMiddleware fallback_model(ModelHandler fallback);

}  // namespace praxo
