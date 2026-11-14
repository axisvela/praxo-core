import core.time : Duration;
import std.stdio;
import praxo.json;
import praxo.mcp;

class FakeTransport : McpTransport {
    JSONValue request(string method, JSONValue params, Duration timeout) {
        if (method == "initialize") {
            return parse(`{"protocolVersion":"2024-11-05","serverInfo":{"name":"example-mcp"}}`);
        }
        if (method == "tools/list") {
            return parse(`{"tools":[{"name":"echo","description":"Echo","inputSchema":{"type":"object"}},{"name":"add","description":"Add","inputSchema":{"type":"object"}}]}`);
        }
        if (method == "tools/call") {
            return parse(`{"structuredContent":{"sum":5}}`);
        }
        return parse(`{}`);
    }

    void notify(string method, JSONValue params) {}
    void close() {}
}

void main() {
    auto client = new McpClient(new FakeTransport(), "2024-11-05");
    client.start();
    auto tools = client.listTools();
    auto result = client.callTool("add", parse(`{}`));
    client.close();
    assert(tools.length == 2 && tools[0].name == "echo" && tools[1].name == "add");
    assert(result == parse(`{"sum":5}`));
    writeln("D MCP example passed");
}
