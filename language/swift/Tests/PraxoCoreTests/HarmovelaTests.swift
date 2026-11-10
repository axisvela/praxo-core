import XCTest
@testable import PraxoCore

private final class RecordingHarmovelaTransport: HarmovelaTransport {
    var requests: [HarmovelaHTTPRequest] = []
    var statusCode: Int
    var body: String

    init(statusCode: Int = 201, body: String = "") {
        self.statusCode = statusCode
        self.body = body
    }

    func send(_ request: HarmovelaHTTPRequest) throws -> HarmovelaHTTPResponse {
        requests.append(request)
        return HarmovelaHTTPResponse(statusCode: statusCode, body: body)
    }
}

final class HarmovelaTests: XCTestCase {
    private let timestamp = HarmovelaTimestamp(
        unixNanos: 1_794_294_000_000_000_000,
        createdAt: "2026-11-10T07:00:00.000000000Z"
    )

    private func sampleEvent() -> Event {
        Event(type: "tool.call", sessionID: "s1", runID: "run-123", data: ["name": "echo"])
    }

    func testPathAndEnvelope() throws {
        let transport = RecordingHarmovelaTransport()
        let sink = HarmovelaSink(
            baseURL: "http://harmovela.test/aep/api/",
            transport: transport,
            clock: { self.timestamp }
        )
        try sink.emit(sampleEvent())

        XCTAssertEqual(transport.requests.count, 1)
        let request = transport.requests[0]
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url, "http://harmovela.test/aep/api/events")
        XCTAssertEqual(request.headers["content-type"], "application/json")

        let decoded = try Json.parse(request.body)
        let envelope = try XCTUnwrap(decoded as? [String: Any])
        XCTAssertEqual(envelope["spec_version"] as? String, "0.2")
        XCTAssertEqual(envelope["id"] as? String, "run-123-1794294000000000000")
        XCTAssertEqual(envelope["type"] as? String, "tool.call")
        XCTAssertEqual(envelope["source"] as? String, "praxo-core")
        XCTAssertEqual(envelope["created_at"] as? String, "2026-11-10T07:00:00.000000000Z")
        let payload = try XCTUnwrap(envelope["payload"] as? [String: Any])
        XCTAssertEqual(payload["name"] as? String, "echo")
        XCTAssertEqual(payload["session_id"] as? String, "s1")
        XCTAssertEqual(payload["run_id"] as? String, "run-123")
    }

    func testSessionFallbackAndPayloadMerge() throws {
        let transport = RecordingHarmovelaTransport()
        let sink = HarmovelaSink(
            baseURL: "http://harmovela.test",
            source: "custom",
            specVersion: "0.3",
            transport: transport,
            clock: { self.timestamp }
        )
        let event = Event(
            type: "tool.call",
            sessionID: "s1",
            runID: "",
            data: ["name": "echo", "session_id": "event-side", "run_id": "old"]
        )
        try sink.emit(event)

        let decoded = try Json.parse(transport.requests[0].body)
        let envelope = try XCTUnwrap(decoded as? [String: Any])
        XCTAssertEqual(envelope["source"] as? String, "custom")
        XCTAssertEqual(envelope["spec_version"] as? String, "0.3")
        XCTAssertTrue((envelope["id"] as? String ?? "").hasPrefix("s1-"))
        let payload = try XCTUnwrap(envelope["payload"] as? [String: Any])
        XCTAssertEqual(payload["session_id"] as? String, "s1")
        XCTAssertEqual(payload["run_id"] as? String, "old")
    }

    func testAcceptedStatuses() throws {
        let transport = RecordingHarmovelaTransport()
        let sink = HarmovelaSink(
            baseURL: "http://harmovela.test",
            transport: transport,
            clock: { self.timestamp }
        )
        for status in [200, 201, 204, 299] {
            transport.statusCode = status
            try sink.emit(sampleEvent())
        }
        XCTAssertEqual(transport.requests.count, 4)
    }

    func testNon2xxIsAnError() throws {
        let transport = RecordingHarmovelaTransport(
            statusCode: 503,
            body: String(repeating: "service down ", count: 100)
        )
        let sink = HarmovelaSink(
            baseURL: "http://harmovela.test",
            transport: transport,
            clock: { self.timestamp }
        )
        XCTAssertThrowsError(try sink.emit(sampleEvent())) { error in
            let raised = error as? PraxoError
            XCTAssertEqual(raised?.code, "HARMOVELA_HTTP")
            XCTAssertTrue(raised?.message.contains("503") ?? false)
            XCTAssertTrue(raised?.message.contains("service down") ?? false)
            XCTAssertLessThanOrEqual(raised?.message.count ?? 0, 600)
        }
    }

    func testMissingBaseURLSkipsTransport() {
        let transport = RecordingHarmovelaTransport()
        let sink = HarmovelaSink(
            baseURL: "",
            transport: transport,
            clock: { self.timestamp }
        )
        XCTAssertThrowsError(try sink.emit(sampleEvent())) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "HARMOVELA_URL")
        }
        XCTAssertEqual(transport.requests.count, 0)
    }
}
