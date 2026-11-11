local errors = require("praxo.errors")

local M = {}

local function request(config, method, params)
  if not config.transport then
    errors.raise("MCP_TRANSPORT", "mcp: transport is required")
  end
  local result, err = config.transport(method, params or {})
  if err then
    errors.raise(err, "mcp: " .. tostring(method) .. " failed")
  end
  return result or {}
end

local function tools_list(client)
  local tools = {}
  local names = {}
  local cursor = nil
  local seen = {}
  repeat
    local params = {}
    if cursor then params.cursor = cursor end
    local result = request(client.config, "tools/list", params)
    for _, tool in ipairs(result.tools or {}) do
      local name = tool.name or ""
      if names[name] then
        errors.raise("MCP_DUPLICATE_TOOL", "mcp: duplicate tool " .. name)
      end
      names[name] = true
      tools[#tools + 1] = tool
    end
    cursor = result.nextCursor
    if cursor and cursor ~= "" then
      if seen[cursor] then
        errors.raise("MCP_PAGINATION", "mcp: repeated cursor")
      end
      seen[cursor] = true
    else
      cursor = nil
    end
  until cursor == nil
  return tools
end

local function call_tool(client, name, arguments)
  local result = request(client.config, "tools/call", {
    name = name,
    arguments = arguments or {},
  })
  if result.isError then
    errors.raise("MCP_TOOL_ERROR", "mcp: tool " .. tostring(name) .. " failed")
  end
  if result.structuredContent ~= nil then
    return result.structuredContent
  end
  local texts = {}
  for _, item in ipairs(result.content or {}) do
    if item.type == "text" then texts[#texts + 1] = item.text or "" end
  end
  if #texts == 0 then return nil end
  if #texts == 1 then return texts[1] end
  return texts
end

function M.new(opts)
  local client = {
    config = {
      transport = opts.transport,
      client_version = opts.client_version or "0.4.1",
      protocol_version = opts.protocol_version or "2024-11-05",
    },
    connected = false,
    closed = false,
    protocol_version = "",
    server_info = {},
  }
  client.start = function()
    if client.connected then return client end
    local result = request(client.config, "initialize", {
      protocolVersion = client.config.protocol_version,
      capabilities = {},
      clientInfo = { name = "praxo-core", version = client.config.client_version },
    })
    if not result.protocolVersion or result.protocolVersion == "" then
      errors.raise("MCP_HANDSHAKE", "mcp: initialize returned no protocol version")
    end
    client.protocol_version = result.protocolVersion
    client.server_info = result.serverInfo or {}
    client.connected = true
    return client
  end
  client.list_tools = function()
    client.start()
    return tools_list(client)
  end
  client.call_tool = function(name, arguments)
    client.start()
    return call_tool(client, name, arguments)
  end
  client.close = function()
    client.closed = true
    client.connected = false
  end
  return client
end

return M
