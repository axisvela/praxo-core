import Foundation

public struct OtelHTTPRequest {
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

public struct OtelHTTPResponse {
    public var statusCode: Int
    public var body: String

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }
}

public protocol OtelTransport {
    func send(_ request: OtelHTTPRequest) throws -> OtelHTTPResponse
}

public final class URLSessionOtelTransport: OtelTransport {
    private let inner: ProviderTransport

    public init(inner: ProviderTransport = URLSessionTransport()) {
        self.inner = inner
    }

    public func send(_ request: OtelHTTPRequest) throws -> OtelHTTPResponse {
        let response = try inner.send(ProviderHTTPRequest(
            method: request.method,
            url: request.url,
            headers: request.headers,
            body: request.body,
            timeout: 30
        ))
        return OtelHTTPResponse(statusCode: response.statusCode, body: response.body)
    }
}

public final class OtelSink {
    public var endpoint: String
    public var serviceName: String
    public var allowedDataKeys: [String]
    public var transport: OtelTransport
    public var clock: () -> Int64

    public init(endpoint: String,
                serviceName: String = "praxo-core",
                allowedDataKeys: [String] = [],
                transport: OtelTransport = URLSessionOtelTransport(),
                clock: @escaping () -> Int64 = {
                    Int64(Date().timeIntervalSince1970 * 1_000_000_000)
                }) {
        self.endpoint = endpoint
        self.serviceName = serviceName
        self.allowedDataKeys = allowedDataKeys
        self.transport = transport
        self.clock = clock
    }

    public func buildRequest(_ event: Event) throws -> OtelHTTPRequest {
        let target = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            throw PraxoError("OTEL_URL", "otel: endpoint is required")
        }
        let nanos = clock()
        let body = try Json.stringify(payload(event, nanos))
        return OtelHTTPRequest(
            method: "POST",
            url: target,
            headers: ["content-type": "application/json"],
            body: body
        )
    }

    public func emit(_ event: Event) throws {
        let response = try transport.send(buildRequest(event))
        guard (200..<300).contains(response.statusCode) else {
            let bounded = response.body.count > 512
                ? String(response.body.prefix(512))
                : response.body
            throw PraxoError("OTEL_HTTP",
                             "otel: HTTP \(response.statusCode): \(bounded.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    private func payload(_ event: Event, _ nanos: Int64) -> [String: Any] {
        let stamp = String(nanos)
        let dataText: String
        if let data = event.data, let encoded = try? Json.stringify(data) {
            dataText = encoded
        } else {
            dataText = ""
        }
        let key = [
            event.sessionID,
            event.runID ?? "",
            event.type,
            stamp,
            dataText,
        ].joined(separator: "|")
        let traceID = stableID("trace-a:" + key) + stableID("trace-b:" + key)
        let spanID = stableID("span:" + key)
        let service = serviceName.isEmpty ? "praxo-core" : serviceName
        var attributes: [[String: Any]] = [
            ["key": "praxo.event.type", "value": ["stringValue": event.type]],
        ]
        if !event.sessionID.isEmpty {
            attributes.append(["key": "praxo.session.id",
                               "value": ["stringValue": event.sessionID]])
        }
        if let runID = event.runID, !runID.isEmpty {
            attributes.append(["key": "praxo.run.id",
                               "value": ["stringValue": runID]])
        }
        attributes.append(["key": "praxo.event.at", "value": ["stringValue": stamp]])
        for name in allowedDataKeys {
            guard let value = event.data?[name] else { continue }
            attributes.append([
                "key": "praxo.event.data." + name,
                "value": ["stringValue": text(value)],
            ])
        }
        let span: [String: Any] = [
            "traceId": traceID,
            "spanId": spanID,
            "name": "praxo." + event.type,
            "kind": 1,
            "startTimeUnixNano": stamp,
            "endTimeUnixNano": stamp,
            "attributes": attributes,
        ]
        return [
            "resourceSpans": [
                [
                    "resource": [
                        "attributes": [
                            ["key": "service.name",
                             "value": ["stringValue": service]],
                        ],
                    ],
                    "scopeSpans": [
                        [
                            "scope": ["name": "praxo-core"],
                            "spans": [span],
                        ],
                    ],
                ],
            ],
        ]
    }

    private func text(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if value is NSNull { return "" }
        if let encoded = try? Json.stringify(value) { return encoded }
        return String(describing: value)
    }

    private func stableID(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}
