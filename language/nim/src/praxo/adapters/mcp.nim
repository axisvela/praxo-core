import std/[json, tables]

import ../errors

type
  McpTransport* = proc(method_name: string, params: JsonNode): JsonNode {.closure.}

  McpClient* = ref object
    transport*: McpTransport
    clientVersion*: string
    protocolVersion*: string
    serverInfo*: JsonNode
    closed*: bool

proc mcpClient*(transport: McpTransport, clientVersion = "0.4.0",
                protocolVersion = "2024-11-05"): McpClient =
  if transport == nil:
    raisePraxo("MCP_TRANSPORT", "mcp: transport is required")
  result = McpClient(
    transport: transport,
    clientVersion: if clientVersion.len > 0: clientVersion else: "0.4.0",
    protocolVersion: if protocolVersion.len > 0: protocolVersion else: "2024-11-05",
    serverInfo: newJObject(),
  )
  let response = transport("initialize", %*{
    "protocolVersion": result.protocolVersion,
    "capabilities": newJObject(),
    "clientInfo": {"name": "praxo-core", "version": result.clientVersion},
  })
  if not response.hasKey("result"):
    raisePraxo("MCP_PROTOCOL", "mcp: initialize result must be an object")
  let data = response["result"]
  if not data.hasKey("protocolVersion") or data["protocolVersion"].getStr.len == 0:
    raisePraxo("MCP_HANDSHAKE", "mcp: initialize returned no protocol version")
  result.protocolVersion = data["protocolVersion"].getStr
  if data.hasKey("serverInfo") and data["serverInfo"].kind == JObject:
    result.serverInfo = data["serverInfo"]

proc listTools*(client: McpClient): seq[JsonNode] =
  var names = initTable[string, bool]()
  var cursors = initTable[string, bool]()
  var cursor = ""
  while true:
    var params = newJObject()
    if cursor.len > 0:
      params["cursor"] = %cursor
    let response = client.transport("tools/list", params)
    if not response.hasKey("result"):
      raisePraxo("MCP_PROTOCOL", "mcp: tools/list result must be an object")
    let data = response["result"]
    if not data.hasKey("tools") or data["tools"].kind != JArray:
      raisePraxo("MCP_PROTOCOL", "mcp: tools/list tools must be an array")
    for item in data["tools"]:
      if item.kind != JObject or not item.hasKey("name"):
        raisePraxo("MCP_PROTOCOL", "mcp: tool definition must be an object")
      let name = item["name"].getStr
      if name.len == 0:
        raisePraxo("MCP_PROTOCOL", "mcp: tool name is required")
      if names.hasKey(name):
        raisePraxo("MCP_DUPLICATE_TOOL", "mcp: duplicate tool " & name)
      names[name] = true
      result.add(item)
    cursor = if data.hasKey("nextCursor") and data["nextCursor"].kind == JString:
      data["nextCursor"].getStr
    else:
      ""
    if cursor.len == 0:
      break
    if cursors.hasKey(cursor):
      raisePraxo("MCP_PAGINATION", "mcp: repeated tool pagination cursor")
    cursors[cursor] = true

proc callTool*(client: McpClient, name: string,
               arguments: JsonNode = newJObject()): JsonNode =
  if name.len == 0:
    raisePraxo("MCP_PROTOCOL", "mcp: tool name is required")
  let response = client.transport("tools/call", %*{
    "name": name,
    "arguments": arguments,
  })
  if not response.hasKey("result"):
    raisePraxo("MCP_PROTOCOL", "mcp: tools/call result must be an object")
  let data = response["result"]
  if data.hasKey("isError") and data["isError"].kind == JBool and data["isError"].getBool:
    raisePraxo("MCP_TOOL_ERROR", "mcp: tool " & name & " failed")
  if data.hasKey("structuredContent"):
    return data["structuredContent"]
  var texts: seq[string]
  if data.hasKey("content") and data["content"].kind == JArray:
    for item in data["content"]:
      if item.kind == JObject and item.hasKey("type") and
          item["type"].getStr == "text" and item.hasKey("text"):
        texts.add(item["text"].getStr)
  if texts.len == 0:
    return newJNull()
  if texts.len == 1:
    return %texts[0]
  result = newJArray()
  for text in texts:
    result.add(%text)

proc close*(client: var McpClient) =
  client.closed = true
