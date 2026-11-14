#include <cassert>
#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>

struct ModelUnavailable : std::runtime_error {
    ModelUnavailable() : std::runtime_error("temporary outage") {}
};

int retry(const std::function<void()>& attempt, int max_attempts) {
    for (int index = 1; index <= max_attempts; index++) {
        try {
            attempt();
            return 0;
        } catch (const ModelUnavailable&) {
            if (index == max_attempts) throw;
        }
    }
    return 0;
}

int main() {
    int calls = 0;
    retry([&] {
        calls++;
        if (calls <= 2) throw ModelUnavailable();
    }, 3);
    assert(calls == 3);

    int exhausted_calls = 0;
    try {
        retry([&] {
            exhausted_calls++;
            throw ModelUnavailable();
        }, 3);
    } catch (const ModelUnavailable&) {
        assert(exhausted_calls == 3);
        std::cout << "C++ retry example passed\n";
        return 0;
    }
    return 1;
}
