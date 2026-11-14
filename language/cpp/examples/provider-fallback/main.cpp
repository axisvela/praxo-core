#include <cassert>
#include <functional>
#include <iostream>
#include <stdexcept>

struct ModelUnavailable : std::runtime_error {
    ModelUnavailable() : std::runtime_error("temporary outage") {}
};

void with_fallback(const std::function<void()>& primary,
                   const std::function<void()>& fallback) {
    try {
        primary();
    } catch (const ModelUnavailable& primary_error) {
        try {
            fallback();
        } catch (const ModelUnavailable&) {
            throw primary_error;
        }
    }
}

int main() {
    int fallback_calls = 0;
    with_fallback([] {}, [&] { fallback_calls++; });
    assert(fallback_calls == 0);

    with_fallback([] { throw ModelUnavailable(); }, [&] { fallback_calls++; });
    assert(fallback_calls == 1);

    try {
        with_fallback([] { throw ModelUnavailable(); },
                      [] { throw ModelUnavailable(); });
    } catch (const ModelUnavailable&) {
        std::cout << "C++ provider fallback example passed\n";
        return 0;
    }
    return 1;
}
