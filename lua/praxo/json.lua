local M = {}

M.null = setmetatable({}, { __tostring = function() return "null" end })
local array_mt = { __json_array = true }

function M.array(value)
  value = value or {}
  return setmetatable(value, array_mt)
end

function M.is_array(value)
  return getmetatable(value) == array_mt
end

function M.is_null(value)
  return value == M.null
end

local function parse_error(message)
  error("invalid JSON: " .. message)
end

local Parser = {}
Parser.__index = Parser

function Parser:new(text)
  return setmetatable({ text = text, pos = 1, length = #text }, self)
end

function Parser:peek()
  return self.text:sub(self.pos, self.pos)
end

function Parser:skip()
  while self.pos <= self.length do
    local c = self:peek()
    if c == " " or c == "\n" or c == "\r" or c == "\t" then
      self.pos = self.pos + 1
    else
      break
    end
  end
end

function Parser:expect(char)
  if self:peek() ~= char then parse_error("expected " .. char) end
  self.pos = self.pos + 1
end

function Parser:parse()
  self:skip()
  local value = self:parse_value()
  self:skip()
  if self.pos <= self.length then parse_error("trailing data") end
  return value
end

function Parser:parse_value()
  self:skip()
  local c = self:peek()
  if c == "n" then return self:literal("null", M.null) end
  if c == "t" then return self:literal("true", true) end
  if c == "f" then return self:literal("false", false) end
  if c == '"' then return self:parse_string() end
  if c == "[" then return self:parse_array() end
  if c == "{" then return self:parse_object() end
  return self:parse_number()
end

function Parser:literal(text, value)
  if self.text:sub(self.pos, self.pos + #text - 1) ~= text then
    parse_error("bad literal")
  end
  self.pos = self.pos + #text
  return value
end

function Parser:parse_array()
  self:expect("[")
  local out = M.array()
  self:skip()
  if self:peek() == "]" then
    self.pos = self.pos + 1
    return out
  end
  while true do
    out[#out + 1] = self:parse_value()
    self:skip()
    local c = self:peek()
    self.pos = self.pos + 1
    if c == "]" then break end
    if c ~= "," then parse_error("expected comma") end
  end
  return out
end

function Parser:parse_object()
  self:expect("{")
  local out = {}
  self:skip()
  if self:peek() == "}" then
    self.pos = self.pos + 1
    return out
  end
  while true do
    self:skip()
    if self:peek() ~= '"' then parse_error("expected key") end
    local key = self:parse_string()
    self:skip()
    self:expect(":")
    out[key] = self:parse_value()
    self:skip()
    local c = self:peek()
    self.pos = self.pos + 1
    if c == "}" then break end
    if c ~= "," then parse_error("expected comma") end
  end
  return out
end

function Parser:parse_string()
  self:expect('"')
  local out = {}
  while true do
    if self.pos > self.length then parse_error("unterminated string") end
    local c = self:peek()
    self.pos = self.pos + 1
    if c == '"' then break end
    if c ~= "\\" then
      out[#out + 1] = c
    else
      local escape = self:peek()
      self.pos = self.pos + 1
      if escape == '"' then out[#out + 1] = '"'
      elseif escape == "\\" then out[#out + 1] = "\\"
      elseif escape == "/" then out[#out + 1] = "/"
      elseif escape == "b" then out[#out + 1] = "\b"
      elseif escape == "f" then out[#out + 1] = "\f"
      elseif escape == "n" then out[#out + 1] = "\n"
      elseif escape == "r" then out[#out + 1] = "\r"
      elseif escape == "t" then out[#out + 1] = "\t"
      elseif escape == "u" then
        local hex = self.text:sub(self.pos, self.pos + 3)
        if #hex < 4 then parse_error("bad unicode") end
        self.pos = self.pos + 4
        out[#out + 1] = utf8.char(tonumber(hex, 16))
      else
        parse_error("unknown escape")
      end
    end
  end
  return table.concat(out)
end

function Parser:parse_number()
  local start = self.pos
  if self:peek() == "-" then self.pos = self.pos + 1 end
  while self:peek():match("%d") do self.pos = self.pos + 1 end
  if self:peek() == "." then
    self.pos = self.pos + 1
    while self:peek():match("%d") do self.pos = self.pos + 1 end
  end
  if self:peek() == "e" or self:peek() == "E" then
    self.pos = self.pos + 1
    if self:peek() == "+" or self:peek() == "-" then self.pos = self.pos + 1 end
    while self:peek():match("%d") do self.pos = self.pos + 1 end
  end
  if self.pos == start then parse_error("expected value") end
  return tonumber(self.text:sub(start, self.pos - 1))
end

function M.parse(text)
  return Parser:new(text):parse()
end

local function escape_string(value)
  return '"' .. value:gsub('[%z\1-\31\\"]', function(c)
    if c == '"' then return '\\"' end
    if c == "\\" then return "\\\\" end
    if c == "\b" then return "\\b" end
    if c == "\f" then return "\\f" end
    if c == "\n" then return "\\n" end
    if c == "\r" then return "\\r" end
    if c == "\t" then return "\\t" end
    return string.format("\\u%04x", c:byte())
  end) .. '"'
end

local is_sequence

function M.encode(value)
  if value == nil or value == M.null then return "null" end
  if value == true then return "true" end
  if value == false then return "false" end
  if type(value) == "number" then
    if math.floor(value) == value then return string.format("%d", value) end
    return string.format("%.17g", value)
  end
  if type(value) == "string" then return escape_string(value) end
  if type(value) == "table" then
    if M.is_array(value) or (is_sequence(value) and next(value) ~= nil) then
      local parts = {}
      for index = 1, #value do parts[#parts + 1] = M.encode(value[index]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
      parts[#parts + 1] = escape_string(key) .. ":" .. M.encode(value[key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  error("cannot encode " .. type(value))
end

is_sequence = function(value)
  if M.is_array(value) then return true end
  if type(value) ~= "table" or M.is_null(value) then return false end
  local count, max_index = 0, 0
  for key in pairs(value) do
    if type(key) ~= "number" or math.floor(key) ~= key or key < 1 then return false end
    count = count + 1
    if key > max_index then max_index = key end
  end
  return count == 0 or count == max_index
end

function M.equals(left, right)
  if left == nil and right == nil then return true end
  if left == nil or right == nil then return false end
  if left == M.null or right == M.null then return left == right end
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  if is_sequence(left) or is_sequence(right) then
    if not (is_sequence(left) and is_sequence(right)) then return false end
    local length = math.max(#left, #right)
    for index = 1, length do
      if not M.equals(left[index], right[index]) then return false end
    end
    return true
  end
  for key, value in pairs(left) do
    if not M.equals(value, right[key]) then return false end
  end
  for key in pairs(right) do
    if left[key] == nil then return false end
  end
  return true
end

function M.get(node, key)
  if type(node) ~= "table" then return nil end
  return node[key]
end

function M.has(node, key)
  return type(node) == "table" and node[key] ~= nil
end

function M.string(node, key)
  local value = M.get(node, key)
  return type(value) == "string" and value or nil
end

function M.bool(node, key, fallback)
  local value = M.get(node, key)
  if type(value) == "boolean" then return value end
  return fallback or false
end

function M.int(node, key, fallback)
  local value = M.get(node, key)
  if type(value) == "number" then return math.tointeger(value) or value end
  return fallback or 0
end

function M.array_of(node, key)
  local value = M.get(node, key)
  if M.is_array(value) then return value end
  return M.array()
end

return M
