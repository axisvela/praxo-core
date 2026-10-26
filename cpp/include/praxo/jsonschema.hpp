#pragma once

#include <string>
#include <vector>

#include "praxo/json.hpp"

namespace praxo {

struct ValidationError {
    std::string path;
    std::string message;
};

std::vector<ValidationError> validate(const Json& schema, const Json& data);

}  // namespace praxo
