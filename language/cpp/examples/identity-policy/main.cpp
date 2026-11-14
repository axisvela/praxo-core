#include <cassert>
#include <iostream>
#include <optional>
#include <string>

#include "praxo/models.hpp"

struct Principal {
    std::string tenant;
    std::string role;
    bool active;
};

praxo::Decision authorize(const Principal* principal,
                          const praxo::Action& action) {
    if (principal == nullptr) return {false, "missing principal"};
    if (!principal->active) return {false, "inactive principal"};
    if (action.kind == "model.generate") return {true, "model"};
    if (principal->role != "operator") return {false, "role"};
    if (!action.arguments.contains("tenant") ||
        action.arguments.at("tenant").as_string() != principal->tenant) {
        return {false, "tenant"};
    }
    if (action.tool_name != std::optional<std::string>("record")) {
        return {false, "operation"};
    }
    return {true, "operator"};
}

int main() {
    Principal operator_principal{"acme", "operator", true};
    Principal viewer{"acme", "viewer", true};
    Principal inactive{"acme", "operator", false};
    praxo::Action model{"model.generate", "s1", std::nullopt, praxo::Json(nullptr)};
    praxo::Action record{
        "tool.invoke", "s1", std::optional<std::string>("record"),
        praxo::Json::parse(R"({"tenant":"acme"})")};

    assert(authorize(&operator_principal, model).allowed);
    assert(authorize(&operator_principal, record).allowed);
    assert(!authorize(&viewer, record).allowed);
    assert(!authorize(&inactive, record).allowed);
    assert(!authorize(nullptr, model).allowed);
    std::cout << "C++ identity policy example passed\n";
    return 0;
}
