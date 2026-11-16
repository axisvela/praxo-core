import std.conv : to;
import std.stdio : writeln;

import authentication : AuthError, ContextAuthenticator, IntrospectionAuthenticator,
    Principal, RevocationClient, Transport, TransportResponse;

struct Call {
    string url;
    string[string] form;
    string authorization;
}

class ScriptedTransport {
    TransportResponse response;
    Call[] calls;

    this(TransportResponse response) {
        this.response = response;
    }

    TransportResponse post(string url, string[string] form, string authorization) {
        calls ~= Call(url, form, authorization);
        return response;
    }

    Transport handler() {
        return &post;
    }
}

class FailingTransport {
    TransportResponse post(string url, string[string] form, string authorization) {
        throw new Exception("unavailable");
    }

    Transport handler() {
        return &post;
    }
}

void check(bool condition, string message) {
    if (!condition) throw new Error(message);
}

string activeBody(long now) {
    return `{"active":true,"sub":"user-1","tenant":"tenant-a","exp":` ~
        (now + 60).to!string ~ `}`;
}

void main() {
    const long now = 1_700_000_000;

    auto context = new ContextAuthenticator("tenant-a");
    auto contextPrincipal = context.authenticate("user-1");
    check(!contextPrincipal.isNull, "context principal");
    check(contextPrincipal.get.subject == "user-1", "context subject");
    check(contextPrincipal.get.tenant == "tenant-a", "context tenant");
    check(contextPrincipal.get.expires.isNull, "context expires");
    check(context.authenticate(null).isNull, "context missing principal");
    check(context.authenticate("").isNull, "context empty principal");

    auto success = new ScriptedTransport(TransportResponse(true, 200, activeBody(now)));
    auto auth = new IntrospectionAuthenticator(
        success.handler(),
        "https://idp.example/introspect",
        "svc",
        "secret",
    );
    auto principal = auth.authenticate("Bearer token-1", now);
    check(!principal.isNull, "introspection success");
    check(principal.get.subject == "user-1", "introspection subject");
    check(principal.get.tenant == "tenant-a", "introspection tenant");
    check(!principal.get.expires.isNull && principal.get.expires.get == now + 60,
        "introspection expires");
    check(success.calls.length == 1, "introspection call count");
    auto call = success.calls[0];
    check(call.url == "https://idp.example/introspect", "introspection endpoint");
    check(call.form["token"] == "token-1", "introspection token");
    check(call.form["client_id"] == "svc", "introspection client id");
    check(call.form["client_secret"] == "secret", "introspection client secret");
    check(call.authorization == "Basic c3ZjOnNlY3JldA==", "introspection basic auth");

    auto local = new ScriptedTransport(TransportResponse(true, 200, activeBody(now)));
    auto localAuth = new IntrospectionAuthenticator(
        local.handler(),
        "https://idp.example",
        "svc",
        "secret",
    );
    check(localAuth.authenticate(null, now).isNull, "missing bearer");
    check(localAuth.authenticate("Basic token", now).isNull, "wrong scheme");
    check(localAuth.authenticate("Bearer   ", now).isNull, "empty token");
    check(local.calls.length == 0, "rejected requests are local");

    string[] rejected = [
        `{"active":false,"sub":"user-1","tenant":"tenant-a","exp":1700000060}`,
        `{"active":true,"sub":"","tenant":"tenant-a","exp":1700000060}`,
        `{"active":true,"tenant":"tenant-a","exp":1700000060}`,
        `{"active":true,"sub":"user-1","tenant":"","exp":1700000060}`,
        `{"active":true,"sub":"user-1","exp":1700000060}`,
        `{"active":true,"sub":"user-1","tenant":"tenant-a","exp":1700000000}`,
        `{"active":true,"sub":"user-1","tenant":"tenant-a"}`,
        "not-json",
        "[]",
    ];
    foreach (body; rejected) {
        auto transport = new ScriptedTransport(TransportResponse(true, 200, body));
        auto rejectAuth = new IntrospectionAuthenticator(
            transport.handler(),
            "https://idp.example",
        );
        check(rejectAuth.authenticate("Bearer token-1", now).isNull,
            "rejected introspection body");
    }

    auto failure = new ScriptedTransport(TransportResponse(true, 500, activeBody(now)));
    auto failureAuth = new IntrospectionAuthenticator(failure.handler(), "https://idp.example");
    check(failureAuth.authenticate("Bearer token-1", now).isNull, "non-200 introspection");

    auto transportError = new FailingTransport();
    auto errorAuth = new IntrospectionAuthenticator(
        transportError.handler(),
        "https://idp.example",
    );
    check(errorAuth.authenticate("Bearer token-1", now).isNull,
        "introspection transport error");

    auto custom = new ScriptedTransport(TransportResponse(
        true,
        200,
        `{"active":true,"sub":"user-1","org":"org-a","exp":1700000060}`,
    ));
    auto customAuth = new IntrospectionAuthenticator(
        custom.handler(),
        "https://idp.example",
        "",
        "",
        "org",
    );
    auto customPrincipal = customAuth.authenticate("Bearer token-1", now);
    check(!customPrincipal.isNull && customPrincipal.get.tenant == "org-a",
        "custom tenant claim");

    auto revocation = new ScriptedTransport(TransportResponse(true, 200, ""));
    auto client = new RevocationClient(
        revocation.handler(),
        "https://idp.example/revoke",
        "svc",
        "secret",
    );
    check(client.revoke("token-1"), "revocation result");
    check(revocation.calls.length == 1, "revocation call count");
    auto revocationCall = revocation.calls[0];
    check(revocationCall.form["token"] == "token-1", "revocation token");
    check(revocationCall.form["token_type_hint"] == "access_token", "revocation hint");
    check(revocationCall.authorization == "Basic c3ZjOnNlY3JldA==", "revocation basic auth");

    auto rejectedRevocation = new ScriptedTransport(TransportResponse(true, 400, ""));
    auto rejectedClient = new RevocationClient(
        rejectedRevocation.handler(),
        "https://idp.example/revoke",
    );
    bool caught = false;
    try {
        rejectedClient.revoke("token-1");
    } catch (AuthError error) {
        caught = true;
        check(error.msg == "token revocation failed", "revocation non-200");
    }
    check(caught, "revocation non-200 thrown");

    auto revocationError = new FailingTransport();
    auto revocationErrorClient = new RevocationClient(
        revocationError.handler(),
        "https://idp.example/revoke",
    );
    caught = false;
    try {
        revocationErrorClient.revoke("token-1");
    } catch (AuthError error) {
        caught = true;
        check(error.msg == "token revocation failed", "revocation transport error");
    }
    check(caught, "revocation transport error thrown");

    auto empty = new ScriptedTransport(TransportResponse(true, 200, ""));
    auto emptyClient = new RevocationClient(empty.handler(), "https://idp.example/revoke");
    caught = false;
    try {
        emptyClient.revoke("");
    } catch (AuthError error) {
        caught = true;
        check(error.msg == "revocation token is required", "revocation empty token");
    }
    check(caught && empty.calls.length == 0, "empty revocation is local");

    writeln("D service auth tests passed");
}
