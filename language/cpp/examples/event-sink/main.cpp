#include <cassert>
#include <iostream>
#include <optional>
#include <string>
#include <vector>

#include "praxo/models.hpp"
#include "praxo/runtime.hpp"

class RecordingSink : public praxo::EventSink {
public:
    std::vector<std::string> kinds;

    void emit(const praxo::Event& event) override {
        kinds.push_back(event.type);
    }
};

int main() {
    RecordingSink all;
    RecordingSink tool;
    praxo::FilterSink filtered(&tool, [](const praxo::Event& event) {
        return event.type == "tool.call";
    });
    std::vector<praxo::EventSink*> sinks{&all, &filtered};
    praxo::MultiSink multi(sinks);

    multi.emit({"run.started", "s1", std::nullopt, {}});
    multi.emit({"tool.call", "s1", std::nullopt, {}});
    multi.emit({"run.completed", "s1", std::nullopt, {}});

    assert(all.kinds == std::vector<std::string>({
        "run.started", "tool.call", "run.completed"}));
    assert(tool.kinds == std::vector<std::string>({"tool.call"}));

    std::cout << "C++ event sink example passed\n";
    return 0;
}
