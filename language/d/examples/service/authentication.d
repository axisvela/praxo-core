import std.base64 : Base64;
import std.conv : to;
import std.json : JSONException, JSONType, JSONValue, parseJSON;
import std.string : startsWith, strip;
import std.typecons : Nullable;

struct Principal {
    string subject;
    string tenant;
    Nullable!long expires;
}

class AuthError : Exception {
    this(string message) {
        super(message);
    }
}

struct TransportResponse {
    bool ok = true;
    int status;
    string body;
}

alias Transport = TransportResponse delegate(string url, string[string] form, string authorization);

class ContextAuthenticator {
    string tenant;

    this(string tenant) {
        this.tenant = tenant;
    }

    Nullable!Principal authenticate(string principal) {
        if (principal is null || principal.length == 0) return Nullable!Principal.init;
        return Nullable!Principal(Principal(principal, tenant, Nullable!long.init));
    }
}

class IntrospectionAuthenticator {
    Transport transport;
    string endpoint;
    string clientId;
    string clientSecret;
    string tenantClaim;

    this(
        Transport transport,
        string endpoint,
        string clientId = "",
        string clientSecret = "",
        string tenantClaim = "tenant",
    ) {
        this.transport = transport;
        this.endpoint = endpoint;
        this.clientId = clientId;
        this.clientSecret = clientSecret;
        this.tenantClaim = tenantClaim.length == 0 ? "tenant" : tenantClaim;
    }

    Nullable!Principal authenticate(string authorization, long now) {
        if (authorization is null || !authorization.startsWith("Bearer ")) {
            return Nullable!Principal.init;
        }
        auto token = authorization["Bearer ".length .. $].strip;
        if (token.length == 0) return Nullable!Principal.init;

        string[string] form = [
            "token": token,
            "client_id": clientId,
            "client_secret": clientSecret,
        ];

        TransportResponse response;
        try {
            response = transport(endpoint, form, basicAuth());
        } catch (Exception) {
            return Nullable!Principal.init;
        }
        if (!response.ok || response.status != 200) return Nullable!Principal.init;

        JSONValue payload;
        try {
            payload = parseJSON(response.body);
        } catch (JSONException) {
            return Nullable!Principal.init;
        }
        if (payload.type != JSONType.object) return Nullable!Principal.init;

        auto active = "active" in payload.object;
        if (active is null || active.type != JSONType.true_) return Nullable!Principal.init;

        auto subject = "sub" in payload.object;
        if (subject is null || subject.type != JSONType.string || subject.str.length == 0) {
            return Nullable!Principal.init;
        }

        auto tenant = tenantClaim in payload.object;
        if (tenant is null || tenant.type != JSONType.string || tenant.str.length == 0) {
            return Nullable!Principal.init;
        }

        auto expires = "exp" in payload.object;
        if (expires is null || expires.type != JSONType.integer || expires.integer <= now) {
            return Nullable!Principal.init;
        }

        return Nullable!Principal(
            Principal(subject.str, tenant.str, Nullable!long(expires.integer))
        );
    }

    string basicAuth() {
        if (clientId.length == 0) return null;
        auto raw = clientId ~ ":" ~ clientSecret;
        return "Basic " ~ to!string(Base64.encode(cast(const(ubyte)[]) raw));
    }
}

class RevocationClient {
    Transport transport;
    string endpoint;
    string clientId;
    string clientSecret;

    this(
        Transport transport,
        string endpoint,
        string clientId = "",
        string clientSecret = "",
    ) {
        this.transport = transport;
        this.endpoint = endpoint;
        this.clientId = clientId;
        this.clientSecret = clientSecret;
    }

    bool revoke(string token) {
        if (token is null || token.length == 0) {
            throw new AuthError("revocation token is required");
        }

        string[string] form = [
            "token": token,
            "token_type_hint": "access_token",
            "client_id": clientId,
            "client_secret": clientSecret,
        ];

        TransportResponse response;
        try {
            response = transport(endpoint, form, basicAuth());
        } catch (Exception) {
            throw new AuthError("token revocation failed");
        }
        if (!response.ok || response.status != 200) {
            throw new AuthError("token revocation failed");
        }
        return true;
    }

    string basicAuth() {
        if (clientId.length == 0) return null;
        auto raw = clientId ~ ":" ~ clientSecret;
        return "Basic " ~ to!string(Base64.encode(cast(const(ubyte)[]) raw));
    }
}
