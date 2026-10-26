local errors = require("praxo.errors")
local json = require("praxo.json")
local jsonschema = require("praxo.jsonschema")

local M = {}

local PII_RULES = {
  { "[%w%._%+%-]+@[%w%.%-]+%.[%a][%a]+", "[REDACTED:email]" },
  { "%d%d%d%-%d%d%-%d%d%d%d", "[REDACTED:ssn]" },
  { "%d%d%d%d[ %-]?%d%d%d%d[ %-]?%d%d%d%d[ %-]?%d%d%d%d", "[REDACTED:credit_card]" },
}

function M.redact(text)
  local output = text or ""
  for _, rule in ipairs(PII_RULES) do
    output = output:gsub(rule[1], rule[2])
  end
  return output
end

function M.redact_value(value)
  if type(value) == "string" then return M.redact(value) end
  if json.is_array(value) then
    local out = json.array()
    for _, item in ipairs(value) do out[#out + 1] = M.redact_value(item) end
    return out
  end
  if type(value) == "table" and not json.is_null(value) then
    local out = {}
    for key, item in pairs(value) do out[key] = M.redact_value(item) end
    return out
  end
  return value
end

local function extract_json(text)
  local value = (text or ""):match("^%s*(.-)%s*$")
  if value:sub(1, 3) == "```" then
    value = value:gsub("^```[^\n]*\n", ""):gsub("^`+", ""):gsub("`+%s*$", "")
    value = value:match("^%s*(.-)%s*$")
  end
  local object = value:find("{", 1, true)
  local array = value:find("[", 1, true)
  local start = nil
  if object and array then start = math.min(object, array)
  else start = object or array end
  if not start then errors.raise("AGENT_STRUCTURED_OUTPUT", "output does not contain JSON") end
  return json.parse(value:sub(start))
end

function M.structured_output(schema, max_repairs, repairer)
  local self = { schema = schema, max_repairs = max_repairs or 0, repairer = repairer }
  function self:apply(text)
    local output = text or ""
    for attempt = 0, self.max_repairs do
      local ok, data = pcall(extract_json, output)
      if ok and #jsonschema.validate(self.schema, data) == 0 then
        return output, nil
      end
      if attempt == self.max_repairs and not self.repairer then break end
      if not self.repairer then break end
      local repaired = self.repairer(output)
      if repaired == nil or repaired:match("^%s*$") then break end
      output = repaired
    end
    return nil, "AGENT_STRUCTURED_OUTPUT"
  end
  return self
end

function M.call_limit(model_limit, tool_limit)
  return {
    model_limit = model_limit,
    tool_limit = tool_limit,
    models = 0,
    tools = 0,
  }
end

function M.call_limit_model(limit)
  limit.models = limit.models + 1
  if limit.model_limit > 0 and limit.models > limit.model_limit then
    errors.raise("AGENT_MODEL_CALL_LIMIT", "model call limit")
  end
end

function M.call_limit_tool(limit)
  limit.tools = limit.tools + 1
  if limit.tool_limit > 0 and limit.tools > limit.tool_limit then
    errors.raise("AGENT_TOOL_CALL_LIMIT", "tool call limit")
  end
end

function M.tool_selection(selected)
  local lookup = {}
  for _, name in ipairs(selected) do lookup[name] = true end
  return { selected = lookup }
end

function M.select_tools(selection, tools)
  local out = {}
  for _, tool in ipairs(tools) do
    if selection.selected[tool.name] then out[#out + 1] = tool end
  end
  return out
end

function M.check_tool_selected(selection, name)
  if not selection.selected[name] then
    errors.raise("AGENT_TOOL_NOT_SELECTED", "tool not selected")
  end
end

function M.fallback_model(fallback)
  return function(next_handler)
    return function(request)
      local ok, response = pcall(next_handler, request)
      if ok then return response end
      if not fallback then error(response) end
      return fallback(request)
    end
  end
end

return M
