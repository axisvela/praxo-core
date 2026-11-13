import XCTest
@testable import PraxoCore

private final class RecordingOtelTransport: OtelTransport {
    var requests: [OtelHTTPRequest] = []
    var statusCode: Int
    var body: String

    init(statusCode: Int = 200, body: String = "") {
        self.statusCode = statusCode
        self.body = body
    }

    func send(_ request: OtelHTTPRequest) throws -> OtelHTTPResponse {
        requests.append(request)
        return OtelHTTPResponse(statusCode: statusCode, body: body)
    }
}

final class SeamTests: XCTestCase {
    private let nanos: Int64 = 1_794_294_000_000_000_000

    private func sampleEvent() -> Event {
        Event(
            type: "tool.call",
            sessionID: "s1",
            runID: "run-123",
            data: ["name": "echo", "secret": "hidden"]
        )
    }

    func testOtelPayloadAndAllowlist() throws {
        let transport = RecordingOtelTransport()
        let sink = OtelSink(
            endpoint: "https://otel.test/v1/traces",
            allowedDataKeys: ["name"],
            transport: transport,
            clock: { self.nanos }
        )
        try sink.emit(sampleEvent())

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url, "https://otel.test/v1/traces")
        XCTAssertEqual(request.headers["content-type"], "application/json")

        let decoded = try Json.parse(request.body)
        let resourceSpans = try XCTUnwrap(decoded as? [String: Any])
        let spans = try XCTUnwrap(resourceSpans["resourceSpans"] as? [Any])
        let resource = try XCTUnwrap(spans.first as? [String: Any])
        let scopeSpans = try XCTUnwrap(resource["scopeSpans"] as? [Any])
        let scope = try XCTUnwrap(scopeSpans.first as? [String: Any])
        let spanList = try XCTUnwrap(scope["spans"] as? [Any])
        let span = try XCTUnwrap(spanList.first as? [String: Any])
        XCTAssertEqual(span["name"] as? String, "praxo.tool.call")
        XCTAssertEqual((span["traceId"] as? String)?.count, 32)
        XCTAssertEqual((span["spanId"] as? String)?.count, 16)
        XCTAssertEqual(span["startTimeUnixNano"] as? String, String(nanos))

        let attributes = try XCTUnwrap(span["attributes"] as? [Any])
        let keys = attributes.compactMap {
            ($0 as? [String: Any])?["key"] as? String
        }
        XCTAssertTrue(keys.contains("praxo.event.data.name"))
        XCTAssertFalse(keys.contains("praxo.event.data.secret"))
    }

    func testOtelNon2xxIsAnError() {
        let transport = RecordingOtelTransport(statusCode: 503, body: "unavailable")
        let sink = OtelSink(
            endpoint: "https://otel.test/v1/traces",
            transport: transport,
            clock: { self.nanos }
        )
        XCTAssertThrowsError(try sink.emit(sampleEvent())) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "OTEL_HTTP")
        }
    }

    func testRetrieverSeam() throws {
        let retriever = FuncRetriever { query, limit in
            [Document(id: "doc-1", content: "\(query):\(limit)")]
        }
        let documents = try retrieveDocuments(
            retriever.retrieve,
            query: "hello",
            limit: 3
        )
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(documents[0].content, "hello:3")
        XCTAssertThrowsError(try retrieveDocuments(retriever.retrieve,
                                                  query: "hello",
                                                  limit: -1)) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "RETRIEVER_INVALID")
        }
    }

    func testDelegationSeam() throws {
        let manager = SubagentManager { _ in
            SubagentResult(taskID: "task-1", agentID: "child", output: "done")
        }
        let request = SubagentRequest(
            parentSessionID: "parent",
            agentID: "child",
            prompt: "look up",
            mode: "fork"
        )
        let task = try manager.run(request)
        XCTAssertEqual(task.status, "completed")
        XCTAssertEqual(task.mode, "fork")
        XCTAssertEqual(task.output, "done")

        let failing = SubagentManager { _ in
            throw PraxoError("BOOM", "boom")
        }
        let failed = try failing.run(request)
        XCTAssertEqual(failed.status, "failed")
        XCTAssertEqual(failed.error, "BOOM")

        XCTAssertThrowsError(try manager.run(SubagentRequest(
            parentSessionID: "",
            agentID: "child",
            prompt: "look up"
        ))) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "SUBAGENT_INVALID")
        }
    }
}
