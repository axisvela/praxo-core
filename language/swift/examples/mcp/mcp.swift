import PraxoCore

final class FakeTransport: McpTransport {
    func request(_ method: String, _ params: [String: Any],
                 timeout: TimeInterval) throws -> [String: Any] {
        switch method {
        case "initialize":
            return ["protocolVersion": "2024-11-05", "serverInfo": ["name": "example-mcp"]]
        case "tools/list":
            return ["tools": [
                ["name": "echo", "description": "Echo", "inputSchema": ["type": "object"]],
                ["name": "add", "description": "Add", "inputSchema": ["type": "object"]],
            ]]
        case "tools/call":
            return ["structuredContent": ["sum": 5]]
        default:
            return [:]
        }
    }

    func notify(_ method: String, _ params: [String: Any]) throws {}
    func close() {}
}

let client = McpClient(transport: FakeTransport())
_ = try client.start()
let tools = try client.listTools()
let result = try client.callTool("add", [:])
client.close()
precondition(tools.map(\.name) == ["echo", "add"])
precondition(result as? [String: Any] != nil)
print("Swift MCP example passed")
