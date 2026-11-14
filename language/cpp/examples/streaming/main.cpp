#include <cassert>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "praxo/agent.hpp"

int main() {
    std::vector<std::string> kinds;
    praxo::AgentOptions options(std::make_shared<praxo::StaticModel>("done"));
    options.on_stream = [&](const praxo::StreamPart& part) {
        kinds.push_back(part.kind);
    };
    auto result = praxo::run_agent(
        std::move(options), praxo::Session{"streaming", {}}, "go");
    assert(result.output == "done");
    assert(kinds == std::vector<std::string>({"values", "messages"}));
    std::cout << "C++ streaming example passed\n";
    return 0;
}
