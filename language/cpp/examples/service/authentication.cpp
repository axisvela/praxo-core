#include "authentication.hpp"

#include <praxo/json.hpp>

#include <cctype>
#include <cmath>
#include <string>
#include <utility>

namespace praxo::examples::service {
namespace {

std::string trim(const std::string& text) {
    std::size_t begin = 0;
    while (begin < text.size() &&
           std::isspace(static_cast<unsigned char>(text[begin]))) {
        ++begin;
    }
    std::size_t end = text.size();
    while (end > begin &&
           std::isspace(static_cast<unsigned char>(text[end - 1]))) {
        --end;
    }
    return text.substr(begin, end - begin);
}

std::string encodeBase64(const std::string& input) {
    static const char table[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    out.reserve(((input.size() + 2) / 3) * 4);
    for (std::size_t index = 0; index < input.size(); index += 3) {
        std::size_t remaining = input.size() - index;
        unsigned int first = static_cast<unsigned char>(input[index]);
        unsigned int second = remaining > 1
            ? static_cast<unsigned char>(input[index + 1])
            : 0;
        unsigned int third = remaining > 2
            ? static_cast<unsigned char>(input[index + 2])
            : 0;
        out.push_back(table[first >> 2]);
        out.push_back(table[((first & 0x03) << 4) | (second >> 4)]);
        out.push_back(remaining > 1
            ? table[((second & 0x0F) << 2) | (third >> 6)]
            : '=');
        out.push_back(remaining > 2 ? table[third & 0x3F] : '=');
    }
    return out;
}

bool integerNumber(const Json& value, double& output) {
    if (!value.is_number()) {
        return false;
    }
    double number = value.as_number();
    if (!std::isfinite(number) || std::floor(number) != number) {
        return false;
    }
    if (number < -9223372036854775808.0 ||
        number >= 9223372036854775808.0) {
        return false;
    }
    output = number;
    return true;
}

}

IntrospectionAuthenticator::IntrospectionAuthenticator(
    IntrospectionTransport transport,
    std::string endpoint,
    std::string clientId,
    std::string clientSecret,
    std::string tenantClaim)
    : transport_(std::move(transport)),
      endpoint_(std::move(endpoint)),
      clientId_(std::move(clientId)),
      clientSecret_(std::move(clientSecret)),
      tenantClaim_(tenantClaim.empty() ? "tenant" : std::move(tenantClaim)) {}

std::optional<std::string> IntrospectionAuthenticator::basicAuth() const {
    if (clientId_.empty()) {
        return std::nullopt;
    }
    return "Basic " + encodeBase64(clientId_ + ":" + clientSecret_);
}

std::optional<AuthenticatedPrincipal> IntrospectionAuthenticator::authenticate(
    const std::optional<std::string>& authorization,
    std::int64_t now) const {
    if (!authorization || authorization->rfind("Bearer ", 0) != 0) {
        return std::nullopt;
    }
    std::string token = trim(authorization->substr(7));
    if (token.empty()) {
        return std::nullopt;
    }
    FormFields form{
        {"token", token},
        {"client_id", clientId_},
        {"client_secret", clientSecret_},
    };
    TransportResponse response;
    try {
        response = transport_(endpoint_, form, basicAuth());
    } catch (...) {
        return std::nullopt;
    }
    if (response.status != 200) {
        return std::nullopt;
    }
    try {
        Json payload = Json::parse(response.body);
        if (!payload.is_object()) {
            return std::nullopt;
        }
        const Json& active = payload.at("active");
        if (!active.is_bool() || !active.as_bool()) {
            return std::nullopt;
        }
        const Json& subject = payload.at("sub");
        const Json& tenant = payload.at(tenantClaim_);
        const Json& expires = payload.at("exp");
        if (!subject.is_string() || subject.as_string().empty()) {
            return std::nullopt;
        }
        if (!tenant.is_string() || tenant.as_string().empty()) {
            return std::nullopt;
        }
        double expiresNumber = 0;
        if (!integerNumber(expires, expiresNumber)) {
            return std::nullopt;
        }
        if (!(expiresNumber > static_cast<double>(now))) {
            return std::nullopt;
        }
        return AuthenticatedPrincipal{
            subject.as_string(),
            tenant.as_string(),
            static_cast<std::int64_t>(expiresNumber),
        };
    } catch (...) {
        return std::nullopt;
    }
}

RevocationClient::RevocationClient(IntrospectionTransport transport,
                                   std::string endpoint,
                                   std::string clientId,
                                   std::string clientSecret)
    : transport_(std::move(transport)),
      endpoint_(std::move(endpoint)),
      clientId_(std::move(clientId)),
      clientSecret_(std::move(clientSecret)) {}

std::optional<std::string> RevocationClient::basicAuth() const {
    if (clientId_.empty()) {
        return std::nullopt;
    }
    return "Basic " + encodeBase64(clientId_ + ":" + clientSecret_);
}

void RevocationClient::revoke(const std::string& token) const {
    if (token.empty()) {
        throw AuthError("revocation token is required");
    }
    FormFields form{
        {"token", token},
        {"token_type_hint", "access_token"},
        {"client_id", clientId_},
        {"client_secret", clientSecret_},
    };
    TransportResponse response;
    try {
        response = transport_(endpoint_, form, basicAuth());
    } catch (...) {
        throw AuthError("token revocation failed");
    }
    if (response.status != 200) {
        throw AuthError("token revocation failed");
    }
}

}
