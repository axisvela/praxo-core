package.path = "language/lua/?.lua;language/lua/?/init.lua;" .. package.path

local mcp = require("praxo.adapters.mcp")

local function transport(method, params)
  if method == "initialize" then
    return {
      protocolVersion = "2024-11-05",
      capabilities = { tools = {} },
      serverInfo = { name = "example-mcp", version = "1.0.0" },
    }
  end
  if method == "tools/list" then
    return {
      tools = {
        { name = "echo", description = "Echo input", inputSchema = { type = "object" } },
        { name = "add", description = "Add two integers", inputSchema = { type = "object" } },
      },
    }
  end
  if method == "tools/call" then
    return { structuredContent = { sum = 5 } }
  end
  return nil, "MCP_RPC"
end

local client = mcp.new({ transport = transport })
local tools = client.list_tools()
local result = client.call_tool("add", { a = 2, b = 3 })
client.close()

assert(tools[1].name == "echo" and tools[2].name == "add")
assert(result.sum == 5)
print("Lua MCP example passed")
