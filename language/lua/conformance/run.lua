package.path = table.concat({
  "language/lua/?.lua",
  "language/lua/?/init.lua",
  "./?.lua",
  "./?/init.lua",
  package.path,
}, ";")

local errors = require("praxo.errors")
local json = require("praxo.json")
local jsonschema = require("praxo.jsonschema")
local middleware = require("praxo.middleware")
local models = require("praxo.models")
local plugin = require("praxo.plugin")
local runtime = require("praxo.runtime")
local toolcall = require("praxo.toolcall")
local agent = require("praxo.agent")

local GROUPS = {
  "agent-loop", "checkpoint", "context", "event", "jsonschema", "memory",
  "middleware", "plugin", "policy", "stream", "toolcall",
}

local function check(condition, message)
  if not condition then error(message) end
end

local function error_code(error_value)
  return errors.code(error_value)
end

local function read_file(path)
  local handle, message = io.open(path, "rb")
  if not handle then error(message) end
  local text = handle:read("*a")
  handle:close()
  return text
end

local function recording_sink()
  local sink = { types = {} }
  sink.emit = function(event) sink.types[#sink.types + 1] = event.type end
  return sink
end

local function scripted_model(steps)
  local next_step = 1
  return {
    generate = function(_request)
      local step = steps[next_step]
      if not step then error("script exhausted") end
      next_step = next_step + 1
      local calls = {}
      for _, item in ipairs(step.toolCalls or {}) do
        calls[#calls + 1] = models.tool_call({
          id = item.id or "", name = item.name or "", arguments = item.arguments or {},
        })
      end
      return models.response({
        message = models.message_assistant(step.content or "", calls),
        usage = models.usage({
          input_tokens = step.inputTokens or 0,
          output_tokens = step.outputTokens or 0,
        }),
      })
    end,
  }
end

local function run_toolcall(input, expect)
  local operation = json.string(input, "operation") or ""
  local content = json.string(input, "content") or ""
  if operation == "strip" then
    local got = toolcall.strip_markup(content)
    check(got == (json.string(expect, "text") or ""), "strip: got " .. got)
    return
  end
  local call = toolcall.parse_toolcall(content)
  if json.bool(expect, "nil") then
    check(call == nil, "expected nil")
    return
  end
  check(call ~= nil, "expected a tool call")
  check(call.name == (json.string(expect, "name") or ""), "name: got " .. call.name)
  check(json.equals(call.input, json.get(expect, "input") or {}), "input mismatch")
end

local function run_jsonschema(input, expect)
  local validation = jsonschema.validate(json.get(input, "schema"), json.get(input, "data"))
  local paths = {}
  for _, error_item in ipairs(validation) do paths[#paths + 1] = error_item.path end
  table.sort(paths)
  local expected = {}
  for _, path in ipairs(json.array_of(expect, "errorPaths")) do expected[#expected + 1] = path end
  table.sort(expected)
  check(#validation == 0 == json.bool(expect, "valid"), "valid mismatch")
  check(json.equals(paths, expected), "errorPaths: got " .. table.concat(paths, ", "))
end

local function run_plugin(input, expect)
  local raw = json.string(input, "raw")
  if raw == nil then raw = json.encode(json.get(input, "manifest") or {}) end
  local ok, manifest = pcall(plugin.parse_manifest, raw)
  if not ok then manifest = nil end
  check((manifest ~= nil) == json.bool(expect, "valid"), "valid mismatch")
  if manifest == nil then return end
  local id = json.string(expect, "id")
  if id ~= nil then check(manifest.id == id, "id: got " .. manifest.id) end
  local kind = json.string(expect, "kind")
  if kind ~= nil then check(manifest.kind == kind, "kind: got " .. manifest.kind) end
end

local function run_memory(input, expect)
  local store = runtime.memory_store()
  for _, put in ipairs(json.array_of(input, "puts")) do
    local record = json.get(put, "record") or {}
    runtime.memory_put(store, json.string(put, "session") or "", models.memory_record({
      id = json.string(record, "id") or "",
      frame = json.string(record, "frame") or "",
      content = json.string(record, "content") or "",
      created_at = json.string(record, "createdAt"),
    }))
  end
  local records = runtime.memory_search(
    store, json.string(input, "session") or "", json.string(input, "query") or "",
    json.int(input, "limit")
  )
  local ids, contents = nil, nil
  if #records > 0 then
    ids, contents = {}, {}
    for index, record in ipairs(records) do
      ids[index] = record.id
      contents[index] = record.content
    end
  end
  local expected_ids = json.get(expect, "ids")
  if expected_ids == json.null then expected_ids = nil end
  local expected_contents = json.get(expect, "contents")
  if expected_contents == json.null then expected_contents = nil end
  check(json.equals(ids, expected_ids), "ids mismatch")
  check(json.equals(contents, expected_contents), "contents mismatch")
end

local function run_event(input, expect)
  local events = {}
  for _, event_type in ipairs(json.array_of(input, "events")) do
    events[#events + 1] = models.event({ type = event_type, session_id = "s1" })
  end
  if (json.string(input, "sink") or "filter") == "multi" then
    local count = math.max(1, json.int(input, "sinkCount", 1))
    local sinks = {}
    for _ = 1, count do sinks[#sinks + 1] = recording_sink() end
    local multi = runtime.multi_sink(sinks)
    for _, event in ipairs(events) do multi.emit(event) end
    local per_sink = {}
    for index, sink in ipairs(sinks) do per_sink[index] = sink.types end
    check(json.equals(per_sink, json.get(expect, "perSink")), "perSink mismatch")
    return
  end
  local sink = recording_sink()
  local predicate = json.get(input, "predicateTypes")
  local allowed = nil
  if predicate ~= nil then
    allowed = {}
    for _, event_type in ipairs(predicate) do allowed[event_type] = true end
  end
  local filter = runtime.filter_sink(sink, function(event)
    return allowed == nil or allowed[event.type] == true
  end)
  for _, event in ipairs(events) do filter.emit(event) end
  local delivered = #sink.types > 0 and sink.types or nil
  check(json.equals(delivered, json.get(expect, "delivered")), "delivered mismatch")
end

local function run_stream(expect)
  check(json.equals(models.STREAM_KINDS, json.get(expect, "kinds")), "kinds mismatch")
end

local function run_checkpoint(input, expect)
  local allowlist = runtime.checkpoint_allowlist()
  for _, payload_type in ipairs(json.array_of(input, "registered")) do
    runtime.checkpoint_register(allowlist, payload_type)
  end
  local operation = json.string(input, "operation") or "roundtrip"
  local payload_type = json.string(input, "type") or ""
  local value = json.get(input, "value")
  if operation == "roundtrip" then
    local data = runtime.checkpoint_marshal(allowlist, payload_type, value)
    check(json.equals(runtime.checkpoint_unmarshal(allowlist, data), json.get(expect, "value")),
          "value mismatch")
    return
  end
  local code = ""
  local ok, result = pcall(function()
    if operation == "marshal" then
      runtime.checkpoint_marshal(allowlist, payload_type, value)
    elseif operation == "unmarshal" then
      runtime.checkpoint_unmarshal(allowlist, json.encode({ type = payload_type, data = value }))
    else
      errors.raise("CHECKPOINT_ERROR", "unknown operation")
    end
  end)
  if not ok then code = error_code(result) end
  check(code == (json.string(expect, "errorCode") or ""), "errorCode: got " .. code)
end

local function run_policy(input, expect)
  local root = "praxo-policy-" .. tostring(math.floor(os.time() * 1000))
  local grants = {}
  for _, item in ipairs(json.array_of(input, "grants")) do
    grants[#grants + 1] = models.path_grant({
      root = root .. "/" .. (json.string(item, "root") or ""),
      access = json.string(item, "access") or "read",
    })
  end
  local checker = runtime.path_checker(grants)
  local target = root .. "/" .. (json.string(input, "target") or "")
  local need = json.string(input, "need") or "read"
  if json.bool(expect, "error") then
    local ok = pcall(runtime.path_check, checker, target, need)
    check(not ok, "expected a policy error")
    return
  end
  local allowed = runtime.path_check(checker, target, need).allowed
  check(allowed == json.bool(expect, "allowed"), "allowed mismatch")
end

local function run_context(input, expect)
  local messages = {}
  for _, item in ipairs(json.array_of(input, "messages")) do
    messages[#messages + 1] = models.message_text(
      json.string(item, "role") or "", json.string(item, "content")
    )
  end
  if (json.string(input, "operation") or "") == "estimate" then
    local tokens = runtime.estimate_tokens(messages)
    check(tokens == json.int(expect, "tokens"), "tokens: got " .. tokens)
    return
  end
  local budget_data = json.get(input, "budget") or {}
  local budget = runtime.context_budget(
    json.int(budget_data, "maxTokens"), json.int(budget_data, "keepRecent")
  )
  local output, ok = runtime.compact_context(budget, messages)
  check(ok == json.bool(expect, "ok"), "ok mismatch")
  if not ok then return end
  local tokens = runtime.estimate_tokens(output)
  check(tokens == json.int(expect, "tokens"), "tokens: got " .. tokens)
  local wire = {}
  for index, message in ipairs(output) do wire[index] = models.message_wire(message) end
  check(json.equals(wire, json.get(expect, "messages")), "messages mismatch")
end

local function run_middleware(input, expect)
  local operation = json.string(input, "operation") or ""
  if operation == "pii" then
    check(middleware.redact(json.string(input, "text") or "") == (json.string(expect, "text") or ""),
          "text mismatch")
  elseif operation == "pii-value" then
    check(json.equals(middleware.redact_value(json.get(input, "value")), json.get(expect, "value")),
          "value mismatch")
  elseif operation == "structured" then
    local repair = json.string(input, "repairOutput")
    local output_object = middleware.structured_output(
      json.get(input, "schema") or {}, json.int(input, "maxRepairs"),
      repair and function(_text) return repair end or nil
    )
    local output, code = output_object:apply(json.string(input, "output") or "")
    if json.bool(expect, "ok") then
      check(output == (json.string(expect, "output") or ""), "output mismatch")
    else
      check(code == (json.string(expect, "errorCode") or ""), "errorCode mismatch")
    end
  elseif operation == "call-limit" then
    local limit = middleware.call_limit(json.int(input, "modelLimit"), json.int(input, "toolLimit"))
    local outcomes = {}
    for _, call in ipairs(json.array_of(input, "calls")) do
      local ok, result = pcall(function()
        if call == "model" then middleware.call_limit_model(limit)
        else middleware.call_limit_tool(limit) end
      end)
      outcomes[#outcomes + 1] = ok and "ok" or error_code(result)
    end
    check(json.equals(outcomes, json.get(expect, "outcomes")), "outcomes mismatch")
  elseif operation == "tool-selection" then
    local selected = {}
    for _, name in ipairs(json.array_of(input, "selected")) do selected[#selected + 1] = name end
    local selection = middleware.tool_selection(selected)
    local tools = {}
    for _, name in ipairs(json.array_of(input, "tools")) do
      tools[#tools + 1] = models.tool_spec({ name = name })
    end
    local advertised = {}
    for _, tool in ipairs(middleware.select_tools(selection, tools)) do
      advertised[#advertised + 1] = tool.name
    end
    check(json.equals(advertised, json.get(expect, "advertised")), "advertised mismatch")
    local ok, result = pcall(middleware.check_tool_selected, selection,
                             json.string(input, "requested") or "")
    local reject = ok and "ok" or error_code(result)
    check(reject == (json.string(expect, "reject") or ""), "reject mismatch")
  elseif operation == "fallback" then
    local content = json.string(input, "fallbackContent") or ""
    local handler = middleware.fallback_model(function(_request)
      return models.response({ message = models.message_assistant(content) })
    end)(function(_request) errors.raise("PRIMARY_FAILED", "primary") end)
    check(handler(models.request()).message.content == content, "output mismatch")
  else
    error("unknown middleware operation " .. operation)
  end
end

local function run_agent_loop(input, expect)
  local invocations = 0
  local registry = agent.tool_registry()
  for _, item in ipairs(json.array_of(input, "tools")) do
    agent.register_tool(registry, agent.func_tool(
      json.string(item, "name") or "", json.string(item, "description") or "",
      function(arguments) invocations = invocations + 1; return arguments end
    ))
  end
  local sink = recording_sink()
  local options = agent.agent_options(scripted_model(json.get(input, "script") or {}))
  options.tools = registry
  options.events = sink
  options.max_steps = json.int(input, "maxSteps")
  options.max_tokens = json.int(input, "maxTokens")
  local ok, result = pcall(agent.run_agent, options,
                           models.session({ id = "s1" }), json.string(input, "prompt") or "")
  if json.bool(expect, "error") then
    check(not ok, "unexpected success")
    local expected = json.string(expect, "errorCode")
    if expected ~= nil then check(error_code(result) == expected, "errorCode mismatch") end
  else
    check(ok, "unexpected failure: " .. tostring(result))
    check(result.output == (json.string(expect, "output") or ""), "output mismatch")
    check(result.steps == json.int(expect, "steps"), "steps mismatch")
  end
  check(invocations == json.int(expect, "toolInvocations"), "tool invocations mismatch")
  local events = #sink.types > 0 and sink.types or nil
  check(json.equals(events, json.get(expect, "events")), "events mismatch")
end

local function run_vector(group, vector)
  local input = json.get(vector, "input") or {}
  local expect = json.get(vector, "expect") or {}
  if group == "toolcall" then run_toolcall(input, expect)
  elseif group == "jsonschema" then run_jsonschema(input, expect)
  elseif group == "plugin" then run_plugin(input, expect)
  elseif group == "memory" then run_memory(input, expect)
  elseif group == "event" then run_event(input, expect)
  elseif group == "stream" then run_stream(expect)
  elseif group == "checkpoint" then run_checkpoint(input, expect)
  elseif group == "policy" then run_policy(input, expect)
  elseif group == "context" then run_context(input, expect)
  elseif group == "middleware" then run_middleware(input, expect)
  elseif group == "agent-loop" then run_agent_loop(input, expect)
  else error("no runner for group " .. group) end
end

local failures = {}
local seen = {}
local version = read_file("spec/SPEC_VERSION"):gsub("%s+$", "")
for _, group in ipairs(GROUPS) do
  local path = "spec/vectors/" .. group .. ".json"
  local content = read_file(path)
  local file = json.parse(content)
  if (json.string(file, "group") or "") ~= group then
    failures[#failures + 1] = group .. ": group mismatch"
  end
  if (json.string(file, "specVersion") or "") ~= version then
    failures[#failures + 1] = group .. ": specVersion mismatch"
  end
  for _, vector in ipairs(json.array_of(file, "vectors")) do
    local id = json.string(vector, "id") or ""
    if seen[id] then
      failures[#failures + 1] = group .. "/" .. id .. ": duplicate id with " .. seen[id]
    end
    seen[id] = group
    local ok, message = pcall(run_vector, group, vector)
    if not ok then
      failures[#failures + 1] = group .. "/" .. id .. ": " .. tostring(message)
    end
  end
end

if #failures == 0 then
  print("all spec vectors passed")
  os.exit(0)
end
for _, failure in ipairs(failures) do
  io.stderr:write(failure .. "\n")
end
os.exit(1)
