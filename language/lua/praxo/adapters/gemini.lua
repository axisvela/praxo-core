local json = require("praxo.json")
local models = require("praxo.models")
local errors = require("praxo.errors")

local M = {}

local function message_parts(message)
  local parts = {}
  if message.content and message.content ~= "" then
    parts[#parts + 1] = { text = message.content }
  end
  for _, block in ipairs(message.content_blocks or {}) do
    if block.type == "text" and block.text and block.text ~= "" then
      parts[#parts + 1] = { text = block.text }
    end
  end
  for _, call in ipairs(message.tool_calls or {}) do
    parts[#parts + 1] = {
      functionCall = { name = call.name, args = call.arguments or {} },
    }
  end
  return parts
end

local function build_contents(messages)
  local system = {}
  local out = {}
  local pending = {}
  local names = {}
  local function flush()
    if #pending > 0 then
      out[#out + 1] = { role = "user", parts = json.array(pending) }
      pending = {}
    end
  end
  for _, message in ipairs(messages or {}) do
    if message.role == models.SYSTEM then
      if message.content and message.content ~= "" then
        system[#system + 1] = { text = message.content }
      end
    elseif message.role == models.TOOL then
      local name = names[message.tool_id or ""] or message.tool_id or "tool"
      pending[#pending + 1] = {
        functionResponse = {
          name = name,
          response = { result = message.content or "" },
        },
      }
    else
      flush()
      local parts = message_parts(message)
      if #parts > 0 then
        out[#out + 1] = {
          role = message.role == models.ASSISTANT and "model" or "user",
          parts = json.array(parts),
        }
      end
      for _, call in ipairs(message.tool_calls or {}) do
        if call.id and call.id ~= "" and call.name and call.name ~= "" then
          names[call.id] = call.name
        end
      end
    end
  end
  flush()
  return system, out
end

local function tool_mode(choice)
  if choice == "required" then return "ANY" end
  if choice == "none" then return "NONE" end
  return "AUTO"
end

local function build_payload(request, config)
  local system, contents = build_contents(request.messages)
  local payload = { contents = json.array(contents) }
  if #system > 0 then
    payload.system_instruction = { parts = json.array(system) }
  end
  local declarations = {}
  for _, tool in ipairs(request.tools or {}) do
    declarations[#declarations + 1] = {
      name = tool.name,
      description = tool.description,
      parameters = tool.parameters or { type = "object", properties = {} },
    }
  end
  if #declarations > 0 then
    payload.tools = json.array({
      { functionDeclarations = json.array(declarations) },
    })
    payload.toolConfig = {
      functionCallingConfig = { mode = tool_mode(request.tool_choice) },
    }
  end
  if (request.temperature and request.temperature ~= 0) or config.max_output_tokens > 0 then
    payload.generationConfig = {
      temperature = request.temperature or 0,
      maxOutputTokens = config.max_output_tokens,
    }
  end
  return payload
end

local function parse_response(data)
  if data.error then
    errors.raise("PROVIDER_HTTP", "gemini: " .. tostring(data.error.message))
  end
  local candidate = (data.candidates and data.candidates[1]) or nil
  if not candidate then
    errors.raise("PROVIDER_HTTP", "gemini: empty response")
  end
  local text = {}
  local calls = {}
  local parts = (candidate.content and candidate.content.parts) or {}
  for _, part in ipairs(parts) do
    if part.text then text[#text + 1] = part.text end
    if part.functionCall then
      calls[#calls + 1] = models.tool_call({
        id = "call-" .. (#calls + 1),
        name = part.functionCall.name or "",
        arguments = part.functionCall.args or {},
      })
    end
  end
  local usage = data.usageMetadata or {}
  return models.response({
    message = models.message({
      role = models.ASSISTANT,
      content = table.concat(text),
      tool_calls = calls,
    }),
    usage = models.usage({
      input_tokens = usage.promptTokenCount or 0,
      output_tokens = usage.candidatesTokenCount or 0,
    }),
    finish_reason = candidate.finishReason,
  })
end

local function default_transport(payload, config)
  local tmp = os.tmpname()
  local handle = assert(io.open(tmp, "wb"))
  handle:write(json.encode(payload))
  handle:close()
  local path = "/v1beta/models/" .. config.model .. ":generateContent"
  local command = string.format(
    'curl -sS -f -X POST %q -H "Content-Type: application/json" -H "x-goog-api-key: %s" --data-binary @%q',
    config.base_url .. path, config.api_key, tmp
  )
  local pipe = io.popen(command, "r")
  local body = pipe:read("*a")
  local ok = pipe:close()
  os.remove(tmp)
  if not ok then errors.raise("PROVIDER_HTTP", "provider request failed") end
  local data = json.parse(body)
  if data == nil then errors.raise("PROVIDER_JSON", "provider returned invalid JSON") end
  return data
end

function M.new(opts)
  local config = {
    base_url = (opts.base_url or "https://generativelanguage.googleapis.com"):gsub("/+$", ""),
    model = opts.model,
    api_key = opts.api_key,
    max_output_tokens = opts.max_output_tokens or 0,
    transport = opts.transport,
  }
  return {
    generate = function(request)
      if not config.api_key or config.api_key == "" then
        errors.raise("MODEL_CONFIG", "gemini: API key is required")
      end
      if not config.model or config.model == "" then
        errors.raise("MODEL_CONFIG", "gemini: model is required")
      end
      local payload = build_payload(request, config)
      local data = config.transport and config.transport(payload)
        or default_transport(payload, config)
      return parse_response(data)
    end,
  }
end

return M
