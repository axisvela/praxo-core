local errors = require("praxo.errors")
local json = require("praxo.json")

local M = {}

local MAX_BODY = 512

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

local function fnv1a(text, seed)
  local value = seed & 0xFFFFFFFF
  for index = 1, #text do
    value = value ~ text:byte(index)
    value = (value * 16777619) & 0xFFFFFFFF
  end
  return value
end

local function hex32(value)
  return string.format("%08x", value & 0xFFFFFFFF)
end

local function attribute(key, value)
  return { key = key, value = { stringValue = tostring(value) } }
end

local function text(value)
  if type(value) == "string" then return value end
  return json.encode(value)
end

function M.new(opts)
  opts = opts or {}
  local config = {
    endpoint = opts.endpoint or "http://127.0.0.1:4318/v1/traces",
    service_name = opts.service_name or "praxo-core",
    transport = opts.transport,
    allowed_data_keys = opts.allowed_data_keys or {},
    clock = opts.clock or default_clock,
  }
  return {
    emit = function(event)
      local seconds, nanos = config.clock()
      local data = type(event.data) == "table" and event.data or {}
      local stamp = os.date("!%Y-%m-%dT%H:%M:%SZ", seconds)
      local key = table.concat({
        event.session_id or "",
        event.run_id or "",
        event.type or "",
        stamp,
        json.encode(data),
      }, "|")
      local trace_id = hex32(fnv1a(key, 2166136261))
        .. hex32(fnv1a(key, 3307539480))
        .. hex32(fnv1a(key, 1540483477))
        .. hex32(fnv1a(key, 2807494644))
      local span_key = key .. "|span"
      local span_id = hex32(fnv1a(span_key, 2166136261))
        .. hex32(fnv1a(span_key, 3307539480))
      local attributes = { attribute("praxo.event.type", event.type or "") }
      if event.session_id and event.session_id ~= "" then
        attributes[#attributes + 1] =
          attribute("praxo.session.id", event.session_id)
      end
      if event.run_id and event.run_id ~= "" then
        attributes[#attributes + 1] = attribute("praxo.run.id", event.run_id)
      end
      attributes[#attributes + 1] = attribute("praxo.event.at", stamp)
      for _, name in ipairs(config.allowed_data_keys) do
        if data[name] ~= nil then
          attributes[#attributes + 1] =
            attribute("praxo.event.data." .. name, text(data[name]))
        end
      end
      local timestamp = tostring(seconds * 1000000000 + nanos)
      local payload = {
        resourceSpans = { {
          resource = {
            attributes = { attribute("service.name", config.service_name) },
          },
          scopeSpans = { {
            scope = { name = "praxo-core" },
            spans = { {
              traceId = trace_id,
              spanId = span_id,
              name = "praxo." .. (event.type or ""),
              kind = 1,
              startTimeUnixNano = timestamp,
              endTimeUnixNano = timestamp,
              attributes = attributes,
            } },
          } },
        } },
      }
      local body = json.encode(payload)
      local response
      if config.transport then
        response = config.transport(config.endpoint, body,
          { ["content-type"] = "application/json" })
      else
        response = post(config.endpoint, body)
      end
      local status = tonumber(response.status) or 0
      if status >= 200 and status < 300 then return end
      local response_body = tostring(response.body or "")
      if #response_body > MAX_BODY then
        response_body = response_body:sub(1, MAX_BODY)
      end
      errors.raise("OTEL_HTTP",
        "otel: HTTP " .. status .. ": " .. response_body)
    end,
  }
end

return M
