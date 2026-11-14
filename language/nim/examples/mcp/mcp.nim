import praxo/adapters/mcp
import praxo/json

proc transport(methodName: string, params: JsonNode): JsonNode =
  if methodName == "initialize":
    return parseJsonText("""{"protocolVersion":"2024-11-05","serverInfo":{"name":"example-mcp"}}""")
  if methodName == "tools/list":
    return parseJsonText("""{"tools":[{"name":"echo","description":"Echo","inputSchema":{"type":"object"}},{"name":"add","description":"Add","inputSchema":{"type":"object"}}]}""")
  if methodName == "tools/call":
    return parseJsonText("""{"structuredContent":{"sum":5}}""")
  newJObject()

let client = mcpClient(transport)
let tools = client.listTools()
let value = client.callTool("add", newJObject())
client.close()
doAssert tools.len == 2
doAssert value["sum"].getInt == 5
echo "Nim MCP example passed"
