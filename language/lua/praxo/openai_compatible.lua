local json = require("praxo.json")
local models = require("praxo.models")
local errors = require("praxo.errors")

local M = {}

local function message_payload(message)
  local content = message.content
  if (content == nil or content == "") and #(message.content_blocks or {}) > 0 then
    local parts = {}
    for _, block in ipairs(message.content_blocks) do
      if block.type == "text" and block.text then parts[#parts + 1] = block.text end
    end
    content = table.concat(parts)
  end
  local out = { role = message.role, content = content }
  if message.role == models.ASSISTANT and #(message.tool_calls or {}) > 0 then
    local calls = {}
    for _, call in ipairs(message.tool_calls) do
      calls[#calls + 1] = {
        id = call.id,
        type = "function",
        ["function"] = {
          name = call.name,
          arguments = json.encode(call.arguments or {}),
        },
      }
    end
    out.tool_calls = json.array(calls)
  end
  if message.role == models.TOOL and message.tool_id then
    out.tool_call_id = message.tool_id
  end
  return out
end

local function build_payload(request, config)
  local messages = {}
  for _, message in ipairs(request.messages or {}) do
    messages[#messages + 1] = message_payload(message)
  end
  local payload = { model = config.model, messages = json.array(messages) }
  local tools = {}
  for _, tool in ipairs(request.tools or {}) do
    tools[#tools + 1] = {
      type = "function",
      ["function"] = {
        name = tool.name,
        description = tool.description,
        parameters = tool.parameters or { type = "object" },
      },
    }
  end
  if #tools > 0 then payload.tools = json.array(tools) end
  if request.tool_choice then payload.tool_choice = request.tool_choice end
  if request.temperature and request.temperature ~= 0 then payload.temperature = request.temperature end
  if request.response_format then payload.response_format = request.response_format end
  return payload
end

local function default_transport(payload, config)
  local tmp = os.tmpname()
  local handle = assert(io.open(tmp, "wb"))
  handle:write(json.encode(payload))
  handle:close()

  local headers = '-H "Content-Type: application/json"'
  if config.api_key then
    headers = headers .. string.format(' -H "Authorization: Bearer %s"', config.api_key)
  end
  local command = string.format(
    'curl -sS -f -X POST %q %s --data-binary @%q',
    config.base_url .. "/chat/completions", headers, tmp
  )
  local pipe = io.popen(command, "r")
  local body = pipe:read("*a")
  local ok = pipe:close()
  os.remove(tmp)
  if not ok then
    errors.raise("PROVIDER_HTTP", "provider request failed")
  end
  local data = json.parse(body)
  if data == nil then
    errors.raise("PROVIDER_JSON", "provider returned invalid JSON")
  end
  return data
end

local function parse_response(data)
  local choice = (data.choices and data.choices[1]) or {}
  local message = choice.message or {}
  local tool_calls = {}
  for _, call in ipairs(message.tool_calls or {}) do
    local fn = call["function"] or {}
    local arguments = {}
    if type(fn.arguments) == "string" and fn.arguments ~= "" then
      arguments = json.parse(fn.arguments) or {}
    end
    tool_calls[#tool_calls + 1] = models.tool_call({
      id = call.id, name = fn.name, arguments = arguments,
    })
  end
  local usage = data.usage or {}
  return models.response({
    message = models.message({
      role = models.ASSISTANT,
      content = message.content,
      tool_calls = tool_calls,
    }),
    usage = models.usage({
      input_tokens = usage.prompt_tokens or 0,
      output_tokens = usage.completion_tokens or 0,
    }),
    finish_reason = choice.finish_reason,
  })
end

function M.new(opts)
  local config = {
    base_url = (opts.base_url or ""):gsub("/+$", ""),
    model = opts.model,
    api_key = opts.api_key,
    transport = opts.transport,
  }
  return {
    generate = function(request)
      local payload = build_payload(request, config)
      local data
      if config.transport then
        data = config.transport(payload)
      else
        data = default_transport(payload, config)
      end
      return parse_response(data)
    end,
  }
end

return M
