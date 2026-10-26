#pragma once

#include <stdexcept>
#include <string>

namespace praxo {

class PraxoError : public std::runtime_error {
public:
    PraxoError(std::string code, const std::string& message)
        : std::runtime_error(message), code_(std::move(code)) {}

    const std::string& code() const { return code_; }

private:
    std::string code_;
};

}  // namespace praxo
