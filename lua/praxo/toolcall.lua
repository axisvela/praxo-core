local json = require("praxo.json")

local M = {}

local function base_call(name, input)
  return {
    call_id = "",
    name = name,
    input = input,
    operation = "",
    resource = "",
    risk = "",
    reason = "",
    idempotency_key = "",
  }
end

function M.parse_input_json(raw)
  local ok, value = pcall(json.parse, raw:match("^%s*(.-)%s*$"))
  if ok and type(value) == "table" and not json.is_array(value) then return value end
  local escaped = raw:gsub("\\", "\\\\")
  ok, value = pcall(json.parse, escaped:match("^%s*(.-)%s*$"))
  if ok and type(value) == "table" and not json.is_array(value) then return value end
  return nil
end

local function parse_json_call(content)
  local ok, value = pcall(json.parse, content)
  if not ok or type(value) ~= "table" or json.is_array(value) then return nil end
  local name = value.name
  if type(name) ~= "string" or name == "" then return nil end
  local call = base_call(name, type(value.input) == "table" and value.input or {})
  call.operation = value.operation or ""
  call.resource = value.resource or ""
  call.risk = value.risk or ""
  call.reason = value.reason or ""
  call.idempotency_key = value.idempotency_key or ""
  return call
end

local function last_match(content, pattern)
  local match = nil
  for name, raw in content:gmatch(pattern) do
    match = { name, raw }
  end
  return match
end

local function parse_xml(content)
  local match = last_match(content, '<tool_call%s+name="([^"]+)"%s*>(.-)</tool_call>')
  if not match then return nil end
  local input = M.parse_input_json(match[2])
  if not input then return nil end
  return base_call(match[1], input)
end

local function parse_tag(content)
  local match = last_match(content, "<([%a][%w%-]*%.[%w%.%-]+)>%s*(%b{})")
  if not match then return nil end
  local input = M.parse_input_json(match[2])
  if not input then return nil end
  return base_call(match[1], input)
end

local function parse_plain(content)
  local name, raw = content:match("^%s*([%a][%w%.%-]*)%s+(%b{})")
  if not name then
    local match = last_match(content, "\n%s*([%a][%w%.%-]*)%s+(%b{})")
    if match then name, raw = match[1], match[2] end
  end
  if not name or not name:find(".", 1, true) then return nil end
  local input = M.parse_input_json(raw)
  if not input then return nil end
  return base_call(name, input)
end

function M.parse_toolcall(content)
  local call = parse_json_call(content) or parse_xml(content) or parse_tag(content) or
                 parse_plain(content)
  if not call then return nil end
  call.call_id = "tc-" .. tostring(math.floor(os.time() * 1000))
  return call
end

function M.strip_markup(content)
  local output = content
  output = output:gsub('<tool_call%s+name="[^"]+"%s*>.-</tool_call>', "")
  output = output:gsub("<tool_call_invoke>.-</tool_call_invoke>", "")
  output = output:gsub("<[%a][%w%-]*%.[%w%.%-]+>%s*%b{}%s*</[%a][%w%.%-]*>", "")
  output = output:gsub("\n\n\n+", "\n\n")
  return output:match("^%s*(.-)%s*$")
end

return M
