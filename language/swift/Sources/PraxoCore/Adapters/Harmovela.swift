import Foundation

public struct HarmovelaTimestamp {
    public var unixNanos: Int64
    public var createdAt: String

    public init(unixNanos: Int64, createdAt: String) {
        self.unixNanos = unixNanos
        self.createdAt = createdAt
    }

    public static func now() -> HarmovelaTimestamp {
        let date = Date()
        let seconds = Int64(date.timeIntervalSince1970.rounded(.down))
        var nanos = Int64(((date.timeIntervalSince1970 - Double(seconds)) * 1_000_000_000).rounded(.down))
        if nanos < 0 { nanos = 0 }
        if nanos > 999_999_999 { nanos = 999_999_999 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let base = formatter.string(from: date)
        let createdAt = String(format: "%@.%09lldZ", base, nanos)
        return HarmovelaTimestamp(unixNanos: seconds * 1_000_000_000 + nanos, createdAt: createdAt)
    }
}

public struct HarmovelaHTTPRequest {
    public var method: String
    public var url: String
    public var headers: [String: String]
    public var body: String

    public init(method: String, url: String, headers: [String: String] = [:], body: String = "") {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct HarmovelaHTTPResponse {
    public var statusCode: Int
    public var body: String

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }
}

public protocol HarmovelaTransport {
    func send(_ request: HarmovelaHTTPRequest) throws -> HarmovelaHTTPResponse
}

public final class URLSessionHarmovelaTransport: HarmovelaTransport {
    private let inner: ProviderTransport

    public init(inner: ProviderTransport = URLSessionTransport()) {
        self.inner = inner
    }

    public func send(_ request: HarmovelaHTTPRequest) throws -> HarmovelaHTTPResponse {
        let response = try inner.send(ProviderHTTPRequest(
            method: request.method,
            url: request.url,
            headers: request.headers,
            body: request.body,
            timeout: 30
        ))
        return HarmovelaHTTPResponse(statusCode: response.statusCode, body: response.body)
    }
}

public final class HarmovelaSink {
    public var baseURL: String
    public var source: String
    public var specVersion: String
    public var transport: HarmovelaTransport
    public var clock: () -> HarmovelaTimestamp

    public init(baseURL: String,
                source: String = "praxo-core",
                specVersion: String = "0.2",
                transport: HarmovelaTransport = URLSessionHarmovelaTransport(),
                clock: @escaping () -> HarmovelaTimestamp = { HarmovelaTimestamp.now() }) {
        self.baseURL = baseURL
        self.source = source
        self.specVersion = specVersion
        self.transport = transport
        self.clock = clock
    }

    public func buildRequest(_ event: Event) throws -> HarmovelaHTTPRequest {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            throw PraxoError("HARMOVELA_URL", "harmovela: base URL is required")
        }
        var trimmed = base
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        let at = clock()
        var payload = event.data ?? [:]
        if !event.sessionID.isEmpty { payload["session_id"] = event.sessionID }
        if let runID = event.runID, !runID.isEmpty { payload["run_id"] = runID }
        let envelope: [String: Any] = [
            "spec_version": specVersion.isEmpty ? "0.2" : specVersion,
            "id": eventID(event, at.unixNanos),
            "type": event.type,
            "source": source.isEmpty ? "praxo-core" : source,
            "created_at": at.createdAt,
            "payload": payload,
        ]
        return HarmovelaHTTPRequest(
            method: "POST",
            url: trimmed + "/events",
            headers: ["content-type": "application/json"],
            body: try Json.stringify(envelope)
        )
    }

    public func emit(_ event: Event) throws {
        let request = try buildRequest(event)
        let response = try transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            let bounded = response.body.count > 512 ? String(response.body.prefix(512)) : response.body
            throw PraxoError("HARMOVELA_HTTP",
                             "harmovela: HTTP \(response.statusCode): \(bounded.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    private func eventID(_ event: Event, _ nanos: Int64) -> String {
        let prefix: String
        if let runID = event.runID, !runID.isEmpty {
            prefix = runID
        } else if !event.sessionID.isEmpty {
            prefix = event.sessionID
        } else {
            prefix = "event"
        }
        return "\(prefix)-\(nanos)"
    }
}
