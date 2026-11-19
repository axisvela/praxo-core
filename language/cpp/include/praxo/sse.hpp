#pragma once

#include <functional>
#include <string>

#include "praxo/models.hpp"

namespace praxo {

std::string parse_sse_stream(const std::string& text);
Response parse_sse_response(
    const std::string& text,
    const std::function<void(const std::string&)>& on_delta = {});

}  // namespace praxo
