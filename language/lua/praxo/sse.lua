local json = require("praxo.json")
local models = require("praxo.models")

local M = {}

function M.parse_response(text, on_delta)
  local content = {}
  local calls = {}
  local input_tokens = 0
  local output_tokens = 0
  local finish_reason = nil
  local done = false
  for line in (text or ""):gmatch("([^\n]*)\n?") do
    local trimmed = line:match("^%s*(.-)%s*$")
    local chunk = trimmed:match("^data:%s*(.*)$")
    if chunk then
      if chunk == "[DONE]" then
        done = true
        break
      elseif chunk ~= "" then
        local ok, event = pcall(json.parse, chunk)
        if not ok or type(event) ~= "table" then return nil, "MODEL_STREAM" end
        local usage = event.usage
        if type(usage) == "table" then
          input_tokens = usage.prompt_tokens or 0
          output_tokens = usage.completion_tokens or 0
        end
        for _, choice in ipairs(event.choices or {}) do
          local delta = choice.delta or {}
          if type(delta.content) == "string" and delta.content ~= "" then
            content[#content + 1] = delta.content
            on_delta(delta.content)
          end
          for _, item in ipairs(delta.tool_calls or {}) do
            local index = item.index or #calls
            local slot = calls[index] or { id = "", name = "", arguments = "" }
            if type(item.id) == "string" then slot.id = slot.id .. item.id end
            local function_value = item["function"] or {}
            if type(function_value.name) == "string" then
              slot.name = slot.name .. function_value.name
            end
            if type(function_value.arguments) == "string" then
              slot.arguments = slot.arguments .. function_value.arguments
            end
            calls[index] = slot
          end
          if choice.finish_reason ~= nil and not json.is_null(choice.finish_reason) then
            finish_reason = choice.finish_reason
            done = true
          end
        end
      end
    end
  end
  if not done then return nil, "MODEL_STREAM" end
  local keys = {}
  for index in pairs(calls) do keys[#keys + 1] = index end
  table.sort(keys)
  local tool_calls = {}
  for _, index in ipairs(keys) do
    local slot = calls[index]
    if slot.name ~= "" then
      local arguments = {}
      if slot.arguments ~= "" then
        local ok, parsed = pcall(json.parse, slot.arguments)
        if not ok or type(parsed) ~= "table" or json.is_array(parsed) then
          return nil, "PROVIDER_JSON"
        end
        arguments = parsed
      end
      tool_calls[#tool_calls + 1] = models.tool_call({
        id = slot.id, name = slot.name, arguments = arguments,
      })
    end
  end
  return models.response({
    message = models.message({
      role = models.ASSISTANT,
      content = table.concat(content),
      tool_calls = tool_calls,
    }),
    usage = models.usage({
      input_tokens = input_tokens,
      output_tokens = output_tokens,
    }),
    finish_reason = finish_reason,
  })
end

function M.parse(text)
  local content = {}
  local done = false
  for line in (text or ""):gmatch("([^\n]*)\n?") do
    local trimmed = line:match("^%s*(.-)%s*$")
    local chunk = trimmed:match("^data:%s*(.*)$")
    if chunk then
      if chunk == "[DONE]" then
        done = true
        break
      elseif chunk ~= "" then
        local ok, event = pcall(json.parse, chunk)
        if not ok then return nil, "MODEL_STREAM" end
        if type(event) == "table" then
          for _, choice in ipairs(event.choices or {}) do
            local delta = choice.delta or {}
            if type(delta.content) == "string" then
              content[#content + 1] = delta.content
            end
            if choice.finish_reason ~= nil and not json.is_null(choice.finish_reason) then
              done = true
            end
          end
        end
      end
    end
  end
  if not done then return nil, "MODEL_STREAM" end
  return table.concat(content)
end

return M
