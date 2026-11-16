import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct AuthenticatedPrincipal {
    let subject: String
    let tenant: String
    let expires: Int
}

struct AuthError: Error {
    let message: String
}

protocol IntrospectionTransport {
    func postForm(url: String, form: [String: String], authorization: String?) throws -> (Int, String)
}

final class URLSessionTransport: IntrospectionTransport {
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 2) {
        self.timeout = timeout
    }

    func postForm(url: String, form: [String: String], authorization: String?) throws -> (Int, String) {
        guard let endpoint = URL(string: url) else {
            throw AuthError(message: "identity provider unavailable")
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)

        let box = TransportResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                box.set(.failure(error))
            } else if let http = response as? HTTPURLResponse, let data {
                box.set(.success((http.statusCode, String(data: data, encoding: .utf8) ?? "")))
            } else {
                box.set(.failure(AuthError(message: "identity provider unavailable")))
            }
            semaphore.signal()
        }
        task.resume()
        if semaphore.wait(timeout: .now() + timeout + 1) == .timedOut {
            task.cancel()
            throw AuthError(message: "identity provider unavailable")
        }
        switch box.get() {
        case .success(let value):
            return value
        case .failure:
            throw AuthError(message: "identity provider unavailable")
        }
    }
}

private final class TransportResultBox {
    private let lock = NSLock()
    private var value: Result<(Int, String), Error> = .failure(AuthError(message: "identity provider unavailable"))

    func set(_ result: Result<(Int, String), Error>) {
        lock.lock()
        value = result
        lock.unlock()
    }

    func get() -> Result<(Int, String), Error> {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

final class IntrospectionAuthenticator {
    let transport: IntrospectionTransport
    let endpoint: String
    let clientId: String
    let clientSecret: String
    let tenantClaim: String

    init(
        transport: IntrospectionTransport,
        endpoint: String,
        clientId: String = "",
        clientSecret: String = "",
        tenantClaim: String = "tenant"
    ) {
        self.transport = transport
        self.endpoint = endpoint
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.tenantClaim = tenantClaim.isEmpty ? "tenant" : tenantClaim
    }

    func authenticate(_ authorization: String?, now: Int? = nil) -> AuthenticatedPrincipal? {
        guard let authorization, authorization.hasPrefix("Bearer ") else {
            return nil
        }
        let token = String(authorization.dropFirst("Bearer ".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            return nil
        }
        let current = now ?? Int(Date().timeIntervalSince1970)
        let form = [
            "token": token,
            "client_id": clientId,
            "client_secret": clientSecret,
        ]
        do {
            let (status, body) = try transport.postForm(
                url: endpoint,
                form: form,
                authorization: basicAuth()
            )
            guard status == 200 else {
                return nil
            }
            guard let payload = try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] else {
                return nil
            }
            guard let active = payload["active"] as? Bool, active else {
                return nil
            }
            guard let subject = payload["sub"] as? String, !subject.isEmpty else {
                return nil
            }
            guard let tenant = payload[tenantClaim] as? String, !tenant.isEmpty else {
                return nil
            }
            guard let expires = jsonInteger(payload["exp"]), expires > current else {
                return nil
            }
            return AuthenticatedPrincipal(subject: subject, tenant: tenant, expires: expires)
        } catch {
            return nil
        }
    }

    private func basicAuth() -> String? {
        guard !clientId.isEmpty else {
            return nil
        }
        let raw = Data("\(clientId):\(clientSecret)".utf8)
        return "Basic \(raw.base64EncodedString())"
    }
}

final class RevocationClient {
    let transport: IntrospectionTransport
    let endpoint: String
    let clientId: String
    let clientSecret: String

    init(
        transport: IntrospectionTransport,
        endpoint: String,
        clientId: String = "",
        clientSecret: String = ""
    ) {
        self.transport = transport
        self.endpoint = endpoint
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    func revoke(_ token: String) throws {
        guard !token.isEmpty else {
            throw AuthError(message: "revocation token is required")
        }
        let form = [
            "token": token,
            "token_type_hint": "access_token",
            "client_id": clientId,
            "client_secret": clientSecret,
        ]
        do {
            let (status, _) = try transport.postForm(
                url: endpoint,
                form: form,
                authorization: basicAuth()
            )
            guard status == 200 else {
                throw AuthError(message: "token revocation failed")
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(message: "token revocation failed")
        }
    }

    private func basicAuth() -> String? {
        guard !clientId.isEmpty else {
            return nil
        }
        let raw = Data("\(clientId):\(clientSecret)".utf8)
        return "Basic \(raw.base64EncodedString())"
    }
}

private func jsonInteger(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber else {
        return nil
    }
    let type = String(cString: number.objCType)
    if type == "c" || type == "B" {
        return nil
    }
    let double = number.doubleValue
    guard double.isFinite, double.rounded(.towardZero) == double else {
        return nil
    }
    guard double >= Double(Int.min), double <= Double(Int.max) else {
        return nil
    }
    return Int(double)
}

final class ScriptedTransport: IntrospectionTransport {
    var status: Int
    var body: String
    var unavailable = false
    private(set) var forms: [[String: String]] = []
    private(set) var authorizations: [String?] = []

    init(status: Int, body: String) {
        self.status = status
        self.body = body
    }

    func postForm(url: String, form: [String: String], authorization: String?) throws -> (Int, String) {
        forms.append(form)
        authorizations.append(authorization)
        if unavailable {
            throw AuthError(message: "identity provider unavailable")
        }
        return (status, body)
    }
}

func runAuthenticationTests() {
    let now = 1_700_000_000

    func body(_ values: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: values)
        return String(data: data, encoding: .utf8)!
    }

    func expect(_ condition: Bool, _ message: String) {
        if !condition {
            fatalError(message)
        }
    }

    let active = ScriptedTransport(
        status: 200,
        body: body([
            "active": true,
            "sub": "user-1",
            "tenant": "local",
            "exp": now + 60,
        ])
    )
    let authenticator = IntrospectionAuthenticator(
        transport: active,
        endpoint: "https://id.example.com/introspect"
    )
    let principal = authenticator.authenticate("Bearer opaque-token", now: now)
    expect(principal?.subject == "user-1", "active token was rejected")
    expect(principal?.tenant == "local", "active token tenant mismatch")
    expect(principal?.expires == now + 60, "active token expiration mismatch")
    expect(active.forms.last?["token"] == "opaque-token", "introspection did not post the token")
    expect(active.authorizations.last == .some(nil), "empty client id must omit authorization")

    expect(authenticator.authenticate(nil, now: now) == nil, "missing authorization was accepted")
    expect(authenticator.authenticate("Basic opaque-token", now: now) == nil, "wrong scheme was accepted")
    expect(authenticator.authenticate("bearer opaque-token", now: now) == nil, "lowercase scheme was accepted")
    expect(authenticator.authenticate("Bearer    ", now: now) == nil, "empty token was accepted")

    let inactive = IntrospectionAuthenticator(
        transport: ScriptedTransport(status: 200, body: body(["active": false])),
        endpoint: "https://id.example.com/introspect"
    )
    expect(inactive.authenticate("Bearer opaque-token", now: now) == nil, "inactive token was accepted")

    let missingSubject = IntrospectionAuthenticator(
        transport: ScriptedTransport(
            status: 200,
            body: body(["active": true, "tenant": "local", "exp": now + 60])
        ),
        endpoint: "https://id.example.com/introspect"
    )
    expect(missingSubject.authenticate("Bearer opaque-token", now: now) == nil, "missing subject was accepted")

    let emptySubject = IntrospectionAuthenticator(
        transport: ScriptedTransport(
            status: 200,
            body: body(["active": true, "sub": "", "tenant": "local", "exp": now + 60])
        ),
        endpoint: "https://id.example.com/introspect"
    )
    expect(emptySubject.authenticate("Bearer opaque-token", now: now) == nil, "empty subject was accepted")

    let missingTenant = IntrospectionAuthenticator(
        transport: ScriptedTransport(
            status: 200,
            body: body(["active": true, "sub": "user-1", "exp": now + 60])
        ),
        endpoint: "https://id.example.com/introspect"
    )
    expect(missingTenant.authenticate("Bearer opaque-token", now: now) == nil, "missing tenant was accepted")

    let emptyTenant = IntrospectionAuthenticator(
        transport: ScriptedTransport(
            status: 200,
            body: body(["active": true, "sub": "user-1", "tenant": "", "exp": now + 60])
        ),
        endpoint: "https://id.example.com/introspect"
    )
    expect(emptyTenant.authenticate("Bearer opaque-token", now: now) == nil, "empty tenant was accepted")

    let expired = IntrospectionAuthenticator(
        transport: ScriptedTransport(
            status: 200,
            body: body(["active": true, "sub": "user-1", "tenant": "local", "exp": now])
        ),
        endpoint: "https://id.example.com/introspect"
    )
    expect(expired.authenticate("Bearer opaque-token", now: now) == nil, "expired token was accepted")

    let malformed = IntrospectionAuthenticator(
        transport: ScriptedTransport(status: 200, body: "{not-json"),
        endpoint: "https://id.example.com/introspect"
    )
    expect(malformed.authenticate("Bearer opaque-token", now: now) == nil, "malformed JSON was accepted")

    let non200 = IntrospectionAuthenticator(
        transport: ScriptedTransport(status: 503, body: "{}"),
        endpoint: "https://id.example.com/introspect"
    )
    expect(non200.authenticate("Bearer opaque-token", now: now) == nil, "non-200 response was accepted")

    let unavailable = ScriptedTransport(status: 200, body: "{}")
    unavailable.unavailable = true
    let unavailableAuth = IntrospectionAuthenticator(
        transport: unavailable,
        endpoint: "https://id.example.com/introspect"
    )
    expect(unavailableAuth.authenticate("Bearer opaque-token", now: now) == nil, "transport error was accepted")

    let customClaim = IntrospectionAuthenticator(
        transport: ScriptedTransport(
            status: 200,
            body: body(["active": true, "sub": "user-1", "org": "acme", "exp": now + 60])
        ),
        endpoint: "https://id.example.com/introspect",
        tenantClaim: "org"
    )
    expect(customClaim.authenticate("Bearer opaque-token", now: now)?.tenant == "acme", "custom tenant claim failed")

    let defaultOnlyClaim = IntrospectionAuthenticator(
        transport: ScriptedTransport(
            status: 200,
            body: body(["active": true, "sub": "user-1", "tenant": "local", "exp": now + 60])
        ),
        endpoint: "https://id.example.com/introspect",
        tenantClaim: "org"
    )
    expect(defaultOnlyClaim.authenticate("Bearer opaque-token", now: now) == nil, "custom tenant claim fallback was accepted")

    let confidential = ScriptedTransport(
        status: 200,
        body: body(["active": true, "sub": "user-1", "tenant": "local", "exp": now + 60])
    )
    let confidentialAuth = IntrospectionAuthenticator(
        transport: confidential,
        endpoint: "https://id.example.com/introspect",
        clientId: "client",
        clientSecret: "secret"
    )
    _ = confidentialAuth.authenticate("Bearer opaque-token", now: now)
    expect(
        confidential.authorizations.last == .some("Basic Y2xpZW50OnNlY3JldA=="),
        "confidential client did not send basic auth"
    )

    let revocationTransport = ScriptedTransport(status: 200, body: "{}")
    let revocation = RevocationClient(
        transport: revocationTransport,
        endpoint: "https://id.example.com/revoke",
        clientId: "client",
        clientSecret: "secret"
    )
    try! revocation.revoke("opaque-token")
    expect(revocationTransport.forms.last?["token"] == "opaque-token", "revocation did not post the token")
    expect(
        revocationTransport.forms.last?["token_type_hint"] == "access_token",
        "revocation did not send the access token hint"
    )

    let failedRevocation = RevocationClient(
        transport: ScriptedTransport(status: 503, body: "{}"),
        endpoint: "https://id.example.com/revoke"
    )
    do {
        try failedRevocation.revoke("opaque-token")
        fatalError("revocation failure was accepted")
    } catch is AuthError {
    } catch {
        fatalError("unexpected revocation error")
    }

    let unavailableRevocation = ScriptedTransport(status: 200, body: "{}")
    unavailableRevocation.unavailable = true
    let unavailableRevocationClient = RevocationClient(
        transport: unavailableRevocation,
        endpoint: "https://id.example.com/revoke"
    )
    do {
        try unavailableRevocationClient.revoke("opaque-token")
        fatalError("revocation transport error was accepted")
    } catch is AuthError {
    } catch {
        fatalError("unexpected revocation transport error")
    }

    do {
        try revocation.revoke("")
        fatalError("empty revocation token was accepted")
    } catch is AuthError {
    } catch {
        fatalError("unexpected empty token error")
    }
}
