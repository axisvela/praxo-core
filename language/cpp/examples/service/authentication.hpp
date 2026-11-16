#pragma once

#include <cstdint>
#include <functional>
#include <map>
#include <optional>
#include <stdexcept>
#include <string>

namespace praxo::examples::service {

struct AuthenticatedPrincipal {
    std::string subject;
    std::string tenant;
    std::int64_t expires = 0;
};

struct TransportResponse {
    int status = 0;
    std::string body;
};

using FormFields = std::map<std::string, std::string>;

using IntrospectionTransport = std::function<TransportResponse(
    const std::string& url,
    const FormFields& form,
    const std::optional<std::string>& authorization)>;

class AuthError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

class IntrospectionAuthenticator {
public:
    IntrospectionAuthenticator(IntrospectionTransport transport,
                               std::string endpoint,
                               std::string clientId = {},
                               std::string clientSecret = {},
                               std::string tenantClaim = "tenant");

    std::optional<AuthenticatedPrincipal> authenticate(
        const std::optional<std::string>& authorization,
        std::int64_t now) const;

private:
    std::optional<std::string> basicAuth() const;

    IntrospectionTransport transport_;
    std::string endpoint_;
    std::string clientId_;
    std::string clientSecret_;
    std::string tenantClaim_;
};

class RevocationClient {
public:
    RevocationClient(IntrospectionTransport transport,
                     std::string endpoint,
                     std::string clientId = {},
                     std::string clientSecret = {});

    void revoke(const std::string& token) const;

private:
    std::optional<std::string> basicAuth() const;

    IntrospectionTransport transport_;
    std::string endpoint_;
    std::string clientId_;
    std::string clientSecret_;
};

}
