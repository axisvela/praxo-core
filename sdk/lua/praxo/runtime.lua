local errors = require("praxo.errors")
local json = require("praxo.json")
local models = require("praxo.models")

local M = {}

function M.multi_sink(sinks)
  return {
    emit = function(event)
      for _, sink in ipairs(sinks) do sink.emit(event) end
    end,
  }
end

function M.filter_sink(sink, predicate)
  return {
    emit = function(event)
      if predicate(event) then sink.emit(event) end
    end,
  }
end

function M.memory_store()
  return { records = {}, sequence = 0 }
end

function M.memory_put(store, session_id, record)
  if record.id == nil or record.id == "" then
    record.id = "mem-" .. tostring(math.floor(os.time() * 1000)) .. "-" .. store.sequence
    store.sequence = store.sequence + 1
  end
  if record.created_at == nil then
    record.created_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  end
  store.records[session_id] = store.records[session_id] or {}
  table.insert(store.records[session_id], record)
  return record
end

function M.memory_search(store, session_id, query, limit)
  local records = store.records[session_id] or {}
  local needle = query:lower():match("^%s*(.-)%s*$")
  local matches = {}
  for _, record in ipairs(records) do
    if needle == "" or record.content:lower():find(needle, 1, true) then
      matches[#matches + 1] = record
    end
  end
  table.sort(matches, function(a, b)
    return (a.created_at or "") > (b.created_at or "")
  end)
  if limit > 0 and #matches > limit then
    local limited = {}
    for index = 1, limit do limited[index] = matches[index] end
    return limited
  end
  return matches
end

function M.checkpoint_allowlist()
  return { registered = {} }
end

function M.checkpoint_register(allow, payload_type)
  if payload_type == nil or payload_type == "" then
    errors.raise("CHECKPOINT_ERROR", "checkpoint: type is required")
  end
  allow.registered[payload_type] = true
end

function M.checkpoint_marshal(allow, payload_type, value)
  if not allow.registered[payload_type] then
    errors.raise("CHECKPOINT_TYPE_NOT_ALLOWED",
                 "checkpoint: payload type not allowed: " .. tostring(payload_type))
  end
  return json.encode({ type = payload_type, data = value == nil and json.null or value })
end

function M.checkpoint_unmarshal(allow, data)
  local envelope = json.parse(data)
  if type(envelope) ~= "table" or json.is_array(envelope) then
    errors.raise("CHECKPOINT_ERROR", "checkpoint: envelope must be an object")
  end
  local payload_type = type(envelope.type) == "string" and envelope.type or ""
  if not allow.registered[payload_type] then
    errors.raise("CHECKPOINT_TYPE_NOT_ALLOWED",
                 "checkpoint: payload type not allowed: " .. payload_type)
  end
  return envelope.data == json.null and nil or envelope.data
end

local function normalize(path)
  path = tostring(path):gsub("\\", "/")
  local prefix = ""
  if path:match("^%a:/") then
    prefix = path:sub(1, 2)
    path = path:sub(3)
  elseif path:sub(1, 1) == "/" then
    prefix = "/"
  end
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      if #parts > 0 then table.remove(parts) end
    elseif part ~= "." and part ~= "" then
      parts[#parts + 1] = part
    end
  end
  local result = prefix .. table.concat(parts, "/")
  if os.getenv("OS") == "Windows_NT" then result = result:lower() end
  return result
end

local function within(root, target)
  local normalized_root = normalize(root)
  local normalized_target = normalize(target)
  if normalized_target == normalized_root then return true end
  return normalized_target:sub(1, #normalized_root + 1) == normalized_root .. "/"
end

local function allows(grant, need)
  if need == "read" then return grant == "read" or grant == "readwrite" end
  if need == "write" then return grant == "write" or grant == "readwrite" end
  return grant == "readwrite"
end

function M.path_checker(grants)
  local normalized = {}
  for _, grant in ipairs(grants) do
    normalized[#normalized + 1] = {
      root = normalize(grant.root),
      access = grant.access or "read",
    }
  end
  return { grants = normalized }
end

function M.path_check(checker, target, need)
  if need ~= "read" and need ~= "write" and need ~= "readwrite" then
    errors.raise("POLICY_ERROR", "policy: invalid access")
  end
  if #checker.grants == 0 then
    return { allowed = false, reason = "no allowed roots" }
  end
  local resolved = normalize(target)
  local matched = nil
  for _, grant in ipairs(checker.grants) do
    if within(grant.root, resolved) then
      matched = grant.root
      if allows(grant.access, need) then
        return { allowed = true, reason = "path within " .. grant.root }
      end
    end
  end
  return { allowed = false, reason = matched and "insufficient grant" or "outside roots" }
end

function M.path_allowed(checker, target, need)
  local ok, decision = pcall(M.path_check, checker, target, need)
  return ok and decision.allowed or false
end

function M.context_budget(max_tokens, keep_recent)
  return { max_tokens = max_tokens, keep_recent = keep_recent }
end

function M.estimate_tokens(messages)
  local total = 0
  for _, message in ipairs(messages) do
    total = total + 4 + math.floor(#(message.content or "") / 4)
    total = total + math.floor(#(message.tool_id or "") / 4)
    for _, block in ipairs(message.content_blocks or {}) do
      total = total + 4 + math.floor(#(block.text or "") / 4)
      total = total + math.floor(#(block.image_url or "") / 4)
      total = total + math.floor(#(block.data or "") / 4)
    end
    for _, call in ipairs(message.tool_calls or {}) do
      total = total + 4 + math.floor(#call.name / 4)
      total = total + math.floor(#json.encode(call.arguments or {}) / 4)
    end
  end
  return total
end

function M.truncate_to_tokens(value, tokens)
  if tokens <= 0 then return "" end
  local limit = tokens * 4
  if #value <= limit then return value end
  if limit <= 16 then return value:sub(1, limit) end
  return value:sub(1, limit - 16) .. "\n[truncated]"
end

function M.compact_context(budget, messages)
  local max = budget.max_tokens
  if max <= 0 or M.estimate_tokens(messages) <= max then return messages, true end
  local system, rest = {}, {}
  for _, message in ipairs(messages) do
    if message.role == models.SYSTEM then
      if not (message.content or ""):match("^%[context compacted:") then
        system[#system + 1] = message
      end
    else
      rest[#rest + 1] = message
    end
  end
  if M.estimate_tokens(system) > max then
    if #system == 0 then return {}, false end
    local first = {}
    for key, value in pairs(system[1]) do first[key] = value end
    first.content = M.truncate_to_tokens(system[1].content or "", max - 4)
    system = { first }
    if M.estimate_tokens(system) > max then return {}, false end
  end
  local keep = budget.keep_recent > 0 and budget.keep_recent or 4
  local start = math.max(0, #rest - keep)
  while start > 0 and rest[start + 1].role == models.TOOL do
    start = start - 1
  end
  local marker = models.message_text(models.SYSTEM,
    "[context compacted: " .. start .. " older messages omitted]")
  local kept = {}
  for index = start + 1, #rest do kept[#kept + 1] = rest[index] end
  local function build()
    local output = {}
    for _, message in ipairs(system) do output[#output + 1] = message end
    if start > 0 then output[#output + 1] = marker end
    for _, message in ipairs(kept) do output[#output + 1] = message end
    return output
  end
  local output = build()
  while M.estimate_tokens(output) > max and #kept > 1 do
    if kept[2].role == models.TOOL then break end
    table.remove(kept, 1)
    output = build()
  end
  return output, M.estimate_tokens(output) <= max
end

return M
