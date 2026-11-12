import XCTest
@testable import PraxoCore

private final class FakeMcpTransport: McpTransport {
    var closed = false
    var notified = ""

    func request(_ method: String, _ params: [String: Any],
                 timeout: TimeInterval) throws -> [String: Any] {
        switch method {
        case "initialize":
            return [
                "protocolVersion": "2025-03-26",
                "serverInfo": ["name": "fake-http"],
            ]
        case "tools/list":
            return [
                "tools": [[
                    "name": "echo",
                    "description": "Echo input",
                    "inputSchema": ["type": "object"],
                ]],
            ]
        case "tools/call":
            return ["content": [["type": "text", "text": "http-ok"]]]
        default:
            return [:]
        }
    }

    func notify(_ method: String, _ params: [String: Any]) throws {
        notified = method
    }

    func close() {
        closed = true
    }
}

final class MCPTests: XCTestCase {
    func testHandshakeListCallAndClose() throws {
        let transport = FakeMcpTransport()
        let client = McpClient(transport: transport, protocolVersion: "2025-03-26")
        _ = try client.start()
        XCTAssertEqual(client.protocolVersion, "2025-03-26")
        XCTAssertEqual(transport.notified, "notifications/initialized")
        let tools = try client.listTools()
        XCTAssertEqual(tools.map(\.name), ["echo"])
        let result = try client.callTool("echo", ["text": "hi"])
        XCTAssertEqual(result as? String, "http-ok")
        client.close()
        XCTAssertTrue(transport.closed)
    }

    func testPlainRemoteHTTPIsRejected() {
        XCTAssertThrowsError(
            try HttpMcpTransport(endpoint: "http://example.com/mcp")
        ) { error in
            XCTAssertEqual((error as? PraxoError)?.code, "MCP_TRANSPORT")
        }
    }
}
