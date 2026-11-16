#include "authentication.hpp"

#include <cassert>
#include <cstdint>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>

using praxo::examples::service::AuthError;
using praxo::examples::service::AuthenticatedPrincipal;
using praxo::examples::service::FormFields;
using praxo::examples::service::IntrospectionAuthenticator;
using praxo::examples::service::IntrospectionTransport;
using praxo::examples::service::RevocationClient;
using praxo::examples::service::TransportResponse;

namespace {

constexpr std::int64_t kNow = 1700000000;

std::string body(int64_t expires) {
    return "{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"tenant-a\","
           "\"exp\":" + std::to_string(expires) + "}";
}

struct FakeTransport {
    int calls = 0;
    std::string url;
    FormFields form;
    std::optional<std::string> authorization;
    TransportResponse response{200, body(kNow + 60)};
    bool error = false;

    IntrospectionTransport transport() {
        return [this](const std::string& callUrl, const FormFields& callForm,
                      const std::optional<std::string>& callAuthorization) {
            ++calls;
            url = callUrl;
            form = callForm;
            authorization = callAuthorization;
            if (error) {
                throw std::runtime_error("unavailable");
            }
            return response;
        };
    }
};

void expectRejected(const std::string& responseBody, int status = 200,
                    bool error = false) {
    FakeTransport fake;
    fake.response = {status, responseBody};
    fake.error = error;
    IntrospectionAuthenticator auth(fake.transport(),
                                    "https://idp.example/introspect");
    auto principal = auth.authenticate(std::string("Bearer token-1"), kNow);
    assert(!principal);
}

void testSuccess() {
    FakeTransport fake;
    IntrospectionAuthenticator auth(fake.transport(),
                                    "https://idp.example/introspect",
                                    "svc", "secret", "tenant");
    auto principal = auth.authenticate(std::string("Bearer token-1"), kNow);
    assert(principal);
    assert(principal->subject == "user-1");
    assert(principal->tenant == "tenant-a");
    assert(principal->expires == kNow + 60);
    assert(fake.calls == 1);
    assert(fake.url == "https://idp.example/introspect");
    assert(fake.form.at("token") == "token-1");
    assert(fake.form.at("client_id") == "svc");
    assert(fake.form.at("client_secret") == "secret");
    assert(fake.authorization);
    assert(*fake.authorization == "Basic c3ZjOnNlY3JldA==");
}

void testLocalRejections() {
    FakeTransport fake;
    IntrospectionAuthenticator auth(fake.transport(),
                                    "https://idp.example/introspect",
                                    "svc", "secret");
    assert(!auth.authenticate(std::nullopt, kNow));
    assert(!auth.authenticate(std::string("Basic token"), kNow));
    assert(!auth.authenticate(std::string("Bearer   "), kNow));
    assert(fake.calls == 0);
}

void testRejectedBodies() {
    expectRejected("{\"active\":false,\"sub\":\"user-1\","
                   "\"tenant\":\"tenant-a\",\"exp\":1700000060}");
    expectRejected("{\"active\":true,\"tenant\":\"tenant-a\","
                   "\"exp\":1700000060}");
    expectRejected("{\"active\":true,\"sub\":\"\",\"tenant\":\"tenant-a\","
                   "\"exp\":1700000060}");
    expectRejected("{\"active\":true,\"sub\":\"user-1\","
                   "\"exp\":1700000060}");
    expectRejected("{\"active\":true,\"sub\":\"user-1\",\"tenant\":\"\","
                   "\"exp\":1700000060}");
    expectRejected("{\"active\":true,\"sub\":\"user-1\","
                   "\"tenant\":\"tenant-a\",\"exp\":1700000000}");
    expectRejected("{\"active\":true,\"sub\":\"user-1\","
                   "\"tenant\":\"tenant-a\"}");
    expectRejected("not-json");
    expectRejected(body(kNow + 60), 500);
    expectRejected(body(kNow + 60), 200, true);
}

void testNoBasicWithoutClientId() {
    FakeTransport fake;
    IntrospectionAuthenticator auth(fake.transport(),
                                    "https://idp.example/introspect");
    auto principal = auth.authenticate(std::string("Bearer token-1"), kNow);
    assert(principal);
    assert(!fake.authorization);
}

void testCustomTenantClaim() {
    FakeTransport fake;
    fake.response = {200,
        "{\"active\":true,\"sub\":\"user-1\",\"org\":\"org-a\","
        "\"exp\":1700000060}"};
    IntrospectionAuthenticator auth(fake.transport(),
                                    "https://idp.example/introspect",
                                    "", "", "org");
    auto principal = auth.authenticate(std::string("Bearer token-1"), kNow);
    assert(principal);
    assert(principal->tenant == "org-a");
}

void testRevocation() {
    FakeTransport fake;
    fake.response = {200, ""};
    RevocationClient client(fake.transport(), "https://idp.example/revoke",
                            "svc", "secret");
    client.revoke("token-1");
    assert(fake.calls == 1);
    assert(fake.form.at("token") == "token-1");
    assert(fake.form.at("token_type_hint") == "access_token");
    assert(fake.form.at("client_id") == "svc");
    assert(fake.form.at("client_secret") == "secret");
    assert(fake.authorization);
    assert(*fake.authorization == "Basic c3ZjOnNlY3JldA==");

    fake.response = {400, ""};
    bool threw = false;
    try {
        client.revoke("token-1");
    } catch (const AuthError& error) {
        threw = std::string(error.what()) == "token revocation failed";
    }
    assert(threw);

    fake.response = {200, ""};
    fake.error = true;
    threw = false;
    try {
        client.revoke("token-1");
    } catch (const AuthError& error) {
        threw = std::string(error.what()) == "token revocation failed";
    }
    assert(threw);

    FakeTransport local;
    RevocationClient localClient(local.transport(),
                                 "https://idp.example/revoke");
    threw = false;
    try {
        localClient.revoke("");
    } catch (const AuthError& error) {
        threw = std::string(error.what()) == "revocation token is required";
    }
    assert(threw);
    assert(local.calls == 0);
}

}

int main() {
    testSuccess();
    testLocalRejections();
    testRejectedBodies();
    testNoBasicWithoutClientId();
    testCustomTenantClaim();
    testRevocation();
    std::cout << "C++ service auth tests passed\n";
    return 0;
}
