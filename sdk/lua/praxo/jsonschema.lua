local json = require("praxo.json")

local M = {}

local function add(errors, path, message)
  errors[#errors + 1] = { path = path, message = message }
end

local function string_length(value)
  local ok, length = pcall(utf8.len, value)
  return ok and length or #value
end

local function check_enum(schema, data, path, errors)
  if not json.is_array(schema.enum) or #schema.enum == 0 then return end
  for _, value in ipairs(schema.enum) do
    if json.equals(value, data) then return end
  end
  add(errors, path, "value not in enum")
end

local visit

local function visit_object(schema, data, path, errors)
  if type(data) ~= "table" or json.is_array(data) then
    add(errors, path, "expected object")
    return
  end
  if json.is_array(schema.required) then
    for _, name in ipairs(schema.required) do
      if type(name) == "string" and data[name] == nil then
        add(errors, path .. "." .. name, "required field missing")
      end
    end
  end
  if type(schema.properties) == "table" and not json.is_array(schema.properties) then
    for name, child in pairs(schema.properties) do
      if data[name] ~= nil then visit(child, data[name], path .. "." .. name, errors) end
    end
  end
end

local function visit_array(schema, data, path, errors)
  if not json.is_array(data) then
    add(errors, path, "expected array")
    return
  end
  if type(schema.items) == "table" and not json.is_array(schema.items) then
    for index, value in ipairs(data) do
      visit(schema.items, value, path .. "[" .. (index - 1) .. "]", errors)
    end
  end
end

local function visit_string(schema, data, path, errors)
  if type(data) ~= "string" then
    add(errors, path, "expected string")
    return
  end
  local length = string_length(data)
  local min = type(schema.minLength) == "number" and schema.minLength or 0
  local max = type(schema.maxLength) == "number" and schema.maxLength or 0
  if min > 0 and length < min then
    add(errors, path, "min length " .. min .. ", got " .. length)
  end
  if max > 0 and length > max then
    add(errors, path, "max length " .. max .. ", got " .. length)
  end
  if type(schema.pattern) == "string" then
    local ok, regex = pcall(string.find, data, schema.pattern)
    if not ok then
      add(errors, path, "invalid pattern '" .. schema.pattern .. "'")
    elseif not regex then
      add(errors, path, "pattern '" .. schema.pattern .. "' not matched")
    end
  end
  check_enum(schema, data, path, errors)
end

local function visit_number(schema, kind, data, path, errors)
  if type(data) ~= "number" then
    add(errors, path, "expected number")
    return
  end
  if kind == "integer" and math.floor(data) ~= data then
    add(errors, path, "expected integer, got " .. data)
    return
  end
  check_enum(schema, data, path, errors)
  if type(schema.minimum) == "number" and schema.minimum ~= 0 and data < schema.minimum then
    add(errors, path, "value below minimum")
  end
  if type(schema.maximum) == "number" and schema.maximum ~= 0 and data > schema.maximum then
    add(errors, path, "value above maximum")
  end
end

local function visit_boolean(schema, data, path, errors)
  if type(data) ~= "boolean" then
    add(errors, path, "expected boolean")
    return
  end
  check_enum(schema, data, path, errors)
end

visit = function(schema, data, path, errors)
  if type(schema) ~= "table" then return end
  local kind = type(schema.type) == "string" and schema.type or ""
  if data == nil or json.is_null(data) then
    if kind ~= "" then add(errors, path, "expected " .. kind .. ", got null") end
    return
  end
  if kind == "object" then visit_object(schema, data, path, errors)
  elseif kind == "array" then visit_array(schema, data, path, errors)
  elseif kind == "string" then visit_string(schema, data, path, errors)
  elseif kind == "number" or kind == "integer" then visit_number(schema, kind, data, path, errors)
  elseif kind == "boolean" then visit_boolean(schema, data, path, errors)
  end
end

function M.validate(schema, data)
  local errors = {}
  visit(schema, data, "$", errors)
  return errors
end

return M
