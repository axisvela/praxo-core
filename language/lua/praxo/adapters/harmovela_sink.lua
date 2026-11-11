local errors = require("praxo.errors")
local json = require("praxo.json")

local M = {}

local MAX_BODY = 1024

local function rfc3339_nano(seconds, nanos)
  return os.date("!%Y-%m-%dT%H:%M:%S", seconds) .. string.format(".%09dZ", nanos)
end

local function default_clock()
  return os.time(), 0
end

local function post(url, body)
  local body_path = os.tmpname()
  local out_path = os.tmpname()
  local handle = assert(io.open(body_path, "wb"))
  handle:write(body)
  handle:close()
  local command = string.format(
    'curl -sS -o %q -w "%%{http_code}" -X POST -H "content-type: application/json" --data-binary @%q %q',
    out_path, body_path, url
  )
  local pipe = io.popen(command, "r")
  local status_text = pipe:read("*a")
  local ok = pipe:close()
  local response_body = ""
  local out = io.open(out_path, "rb")
  if out then
    response_body = out:read("*a") or ""
    out:close()
  end
  os.remove(body_path)
  os.remove(out_path)
  if not ok then
    return { status = 0, body = "request failed" }
  end
  return { status = tonumber(status_text) or 0, body = response_body }
end

function M.new(opts)
  opts = opts or {}
  local config = {
    base_url = (opts.base_url or ""):gsub("/+$", ""),
    source = opts.source,
    spec_version = opts.spec_version,
    transport = opts.transport,
    clock = opts.clock or default_clock,
  }
  return {
    emit = function(event)
      if config.base_url == "" then
        errors.raise("HARMOVELA_URL", "harmovela: base URL is required")
      end
      local seconds, nanos = config.clock()
      local prefix = event.run_id
      if prefix == nil or prefix == "" then prefix = event.session_id end
      if prefix == nil or prefix == "" then prefix = "event" end
      local payload = {}
      if type(event.data) == "table" and not json.is_array(event.data) then
        for key, value in pairs(event.data) do payload[key] = value end
      end
      if event.session_id ~= nil and event.session_id ~= "" then
        payload.session_id = event.session_id
      end
      if event.run_id ~= nil and event.run_id ~= "" then
        payload.run_id = event.run_id
      end
      local envelope = {
        spec_version = config.spec_version or "0.2",
        id = prefix .. "-" .. tostring(seconds * 1000000000 + nanos),
        type = event.type,
        source = config.source or "praxo-core",
        created_at = rfc3339_nano(seconds, nanos),
        payload = payload,
      }
      local body = json.encode(envelope)
      local response
      if config.transport then
        response = config.transport("/events", body, { ["content-type"] = "application/json" })
      else
        response = post(config.base_url .. "/events", body)
      end
      local status = tonumber(response.status) or 0
      if status >= 200 and status < 300 then return end
      local text = tostring(response.body or "")
      if #text > MAX_BODY then text = text:sub(1, MAX_BODY) end
      errors.raise("HARMOVELA_HTTP", "harmovela: HTTP " .. status .. ": " .. text)
    end,
  }
end

return M
