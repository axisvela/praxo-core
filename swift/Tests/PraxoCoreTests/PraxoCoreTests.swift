import XCTest
@testable import PraxoCore

final class PraxoCoreTests: XCTestCase {
    func testToolCallJson() throws {
        let call = ToolCallParser.parse("{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}")
        XCTAssertNotNil(call)
        XCTAssertEqual(call?.name, "echo")
        XCTAssertEqual(call?.input["text"] as? String, "hi")
    }

    func testToolCallStrip() {
        let text = ToolCallParser.stripMarkup(
            "hello<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>world"
        )
        XCTAssertEqual(text, "helloworld")
    }

    func testJsonSchemaRequired() {
        let schema = try? Json.parse(
            "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}"
        )
        let errors = JsonSchema.validate(schema, [String: Any]())
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first?.path, "$.name")
    }

    func testPluginManifest() throws {
        let manifest = try Plugin.parseManifest(
            "{\"schemaVersion\":1,\"id\":\"com.example.echo\",\"version\":\"1.0.0\",\"kind\":\"tool.provider.v1\",\"entrypoint\":{\"type\":\"process\",\"command\":\"echo\"},\"protocol\":\"jsonrpc-2\",\"capabilities\":[],\"permissions\":{},\"limits\":{},\"health\":{},\"isolation\":\"process\"}"
        )
        XCTAssertEqual(manifest.id, "com.example.echo")
    }
}
