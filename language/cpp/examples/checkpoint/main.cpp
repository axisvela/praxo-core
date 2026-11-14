#include <cassert>
#include <iostream>
#include <string>

#include "praxo/errors.hpp"
#include "praxo/json.hpp"
#include "praxo/runtime.hpp"

int main() {
    praxo::CheckpointAllowlist allowlist;
    allowlist.register_type("order");
    auto value = praxo::Json::parse(R"({"value":"x"})");
    auto encoded = allowlist.marshal("order", value);
    assert(allowlist.unmarshal(encoded) == value);

    bool denied = false;
    try {
        allowlist.marshal("missing", value);
    } catch (const praxo::PraxoError& error) {
        denied = std::string(error.code()) == "CHECKPOINT_TYPE_NOT_ALLOWED";
    }
    assert(denied);

    std::cout << "C++ checkpoint example passed\n";
    return 0;
}

