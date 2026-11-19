local json = require("praxo.json")
local models = require("praxo.models")
local errors = require("praxo.errors")

local M = {}

local function message_content(message)
  local content = {}
  if message.content and message.content ~= "" then
    content[#content + 1] = { type = "text", text = message.content }
  end
  for _, block in ipairs(message.content_blocks or {}) do
    if block.type == "text" and block.text and block.text ~= "" then
      content[#content + 1] = { type = "text", text = block.text }
    end
  end
  for _, call in ipairs(message.tool_calls or {}) do
    content[#content + 1] = {
      type = "tool_use",
      id = call.id,
      name = call.name,
      input = call.arguments or {},
    }
  end
  return content
end

local function build_messages(messages)
  local system = {}
  local out = {}
  local pending = {}
  local function flush()
    if #pending > 0 then
      out[#out + 1] = { role = "user", content = json.array(pending) }
      pending = {}
    end
  end
  for _, message in ipairs(messages or {}) do
    if message.role == models.SYSTEM then
      if message.content and message.content ~= "" then
        system[#system + 1] = message.content
      end
    elseif message.role == models.TOOL then
      pending[#pending + 1] = {
        type = "tool_result",
        tool_use_id = message.tool_id or "",
        content = message.content or "",
      }
    else
      flush()
      local content = message_content(message)
      if #content > 0 then
        out[#out + 1] = { role = message.role, content = json.array(content) }
      end
    end
  end
  flush()
  return table.concat(system, "\n\n"), out
end

local function tool_choice(choice)
  if choice == "auto" then return { type = "auto" } end
  if choice == "required" then return { type = "any" } end
  if choice == "none" then return { type = "none" } end
  return nil
end

local function build_payload(request, config, stream)
  local system, messages = build_messages(request.messages)
  local payload = {
    model = config.model,
    max_tokens = config.max_tokens,
    messages = json.array(messages),
  }
  if system ~= "" then payload.system = system end
  local tools = {}
  for _, tool in ipairs(request.tools or {}) do
    tools[#tools + 1] = {
      name = tool.name,
      description = tool.description,
      input_schema = tool.parameters or { type = "object", properties = {} },
    }
  end
  if #tools > 0 then
    payload.tools = json.array(tools)
    local choice = tool_choice(request.tool_choice)
    if choice then payload.tool_choice = choice end
  end
  if request.temperature and request.temperature ~= 0 then
    payload.temperature = request.temperature
  end
  if stream then payload.stream = true end
  return payload
end

local function default_stream_transport(payload, config)
  local tmp = os.tmpname()
  local handle = assert(io.open(tmp, "wb"))
  handle:write(json.encode(payload))
  handle:close()
  local headers = string.format(
    '-H "Content-Type: application/json" -H "Accept: text/event-stream" -H "x-api-key: %s" -H "anthropic-version: %s"',
    config.api_key, config.version
  )
  local command = string.format(
    'curl -sS -N -f -X POST %q %s --data-binary @%q',
    config.base_url .. "/v1/messages", headers, tmp
  )
  local pipe = io.popen(command, "r")
  local body = pipe:read("*a")
  local ok = pipe:close()
  os.remove(tmp)
  if not ok then errors.raise("PROVIDER_HTTP", "provider request failed") end
  return body
end

local function parse_sse(text, on_delta)
  local content = {}
  local calls = {}
  local input_tokens = 0
  local output_tokens = 0
  local cached_tokens = 0
  local stop_reason = nil
  local stopped = false
  for line in (text or ""):gmatch("([^\n]*)\n?") do
    local trimmed = line:match("^%s*(.-)%s*$")
    local chunk = trimmed:match("^data:%s*(.*)$")
    if chunk and chunk ~= "" then
      local ok, event = pcall(json.parse, chunk)
      if not ok or type(event) ~= "table" then return nil, "MODEL_STREAM" end
      if event.type == "message_start" then
        local usage = (event.message or {}).usage or {}
        input_tokens = usage.input_tokens or 0
        cached_tokens = usage.cache_read_input_tokens or 0
      elseif event.type == "content_block_start" then
        local index = event.index or 0
        local block = event.content_block or {}
        if block.type == "tool_use" then
          calls[index] = { id = block.id or "", name = block.name or "", arguments = "" }
        end
      elseif event.type == "content_block_delta" then
        local index = event.index or 0
        local delta = event.delta or {}
        if delta.type == "text_delta" then
          local piece = delta.text or ""
          if piece ~= "" then
            content[#content + 1] = piece
            on_delta(piece)
          end
        elseif delta.type == "input_json_delta" and calls[index] then
          calls[index].arguments = calls[index].arguments .. (delta.partial_json or "")
        end
      elseif event.type == "message_delta" then
        stop_reason = (event.delta or {}).stop_reason or stop_reason
        output_tokens = (event.usage or {}).output_tokens or output_tokens
      elseif event.type == "message_stop" then
        stopped = true
      elseif event.type == "error" then
        return nil, "MODEL_STREAM"
      end
    end
  end
  if not stopped and stop_reason == nil then return nil, "MODEL_STREAM" end
  local keys = {}
  for index in pairs(calls) do keys[#keys + 1] = index end
  table.sort(keys)
  local tool_calls = {}
  for _, index in ipairs(keys) do
    local call = calls[index]
    if call.name ~= "" then
      local arguments = {}
      if call.arguments ~= "" then
        local ok, parsed = pcall(json.parse, call.arguments)
        if not ok or type(parsed) ~= "table" or json.is_array(parsed) then
          return nil, "PROVIDER_JSON"
        end
        arguments = parsed
      end
      tool_calls[#tool_calls + 1] = models.tool_call({
        id = call.id, name = call.name, arguments = arguments,
      })
    end
  end
  local response = models.response({
    message = models.message({
      role = models.ASSISTANT,
      content = table.concat(content),
      tool_calls = tool_calls,
    }),
    usage = models.usage({
      input_tokens = input_tokens,
      output_tokens = output_tokens,
      cached_tokens = cached_tokens,
    }),
    finish_reason = stop_reason,
  })
  return response
end

local function parse_response(data)
  if data.error then
    errors.raise("PROVIDER_HTTP", "anthropic: " .. tostring(data.error.message))
  end
  local text = {}
  local calls = {}
  for _, block in ipairs(data.content or {}) do
    if block.type == "text" then
      text[#text + 1] = block.text or ""
    elseif block.type == "tool_use" then
      calls[#calls + 1] = models.tool_call({
        id = block.id or ("call-" .. (#calls + 1)),
        name = block.name or "",
        arguments = block.input or {},
      })
    end
  end
  local usage = data.usage or {}
  return models.response({
    message = models.message({
      role = models.ASSISTANT,
      content = table.concat(text),
      tool_calls = calls,
    }),
    usage = models.usage({
      input_tokens = usage.input_tokens or 0,
      output_tokens = usage.output_tokens or 0,
    }),
    finish_reason = data.stop_reason,
  })
end

local function default_transport(payload, config)
  local tmp = os.tmpname()
  local handle = assert(io.open(tmp, "wb"))
  handle:write(json.encode(payload))
  handle:close()
  local headers = string.format(
    '-H "Content-Type: application/json" -H "x-api-key: %s" -H "anthropic-version: %s"',
    config.api_key, config.version
  )
  local command = string.format(
    'curl -sS -f -X POST %q %s --data-binary @%q',
    config.base_url .. "/v1/messages", headers, tmp
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
    base_url = (opts.base_url or "https://api.anthropic.com"):gsub("/+$", ""),
    model = opts.model,
    api_key = opts.api_key,
    version = opts.version or "2023-06-01",
    max_tokens = opts.max_tokens or 1024,
    transport = opts.transport,
    stream_transport = opts.stream_transport,
  }
  return {
    generate = function(request)
      if not config.api_key or config.api_key == "" then
        errors.raise("MODEL_CONFIG", "anthropic: API key is required")
      end
      if not config.model or config.model == "" then
        errors.raise("MODEL_CONFIG", "anthropic: model is required")
      end
      local payload = build_payload(request, config)
      local data = config.transport and config.transport(payload)
        or default_transport(payload, config)
      return parse_response(data)
    end,
    stream = function(request, on_delta)
      if not config.api_key or config.api_key == "" then
        errors.raise("MODEL_CONFIG", "anthropic: API key is required")
      end
      if not config.model or config.model == "" then
        errors.raise("MODEL_CONFIG", "anthropic: model is required")
      end
      local payload = build_payload(request, config, true)
      local text = config.stream_transport and config.stream_transport(payload)
        or default_stream_transport(payload, config)
      local response, code = parse_sse(text, on_delta)
      if not response then errors.raise(code, "anthropic: stream failed") end
      return response
    end,
  }
end

return M
