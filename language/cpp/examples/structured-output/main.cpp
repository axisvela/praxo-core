#include <cassert>
#include <iostream>

#include "praxo/jsonschema.hpp"

int main() {
    auto schema = praxo::Json::parse(
        R"({"type":"object","required":["name"],"properties":{"name":{"type":"string"}}})");
    assert(praxo::validate(schema, praxo::Json::parse(R"({"name":"ok"})")).empty());
    assert(!praxo::validate(schema, praxo::Json::parse("{}")).empty());
    std::cout << "C++ structured output example passed\n";
    return 0;
}
