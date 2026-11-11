package.path = table.concat({ "language/lua/?.lua", "language/lua/?/init.lua", "./?.lua", package.path }, ";")

local agent = require("praxo.agent")
local errors = require("praxo.errors")
local json = require("praxo.json")
local jsonschema = require("praxo.jsonschema")
local middleware = require("praxo.middleware")
local models = require("praxo.models")
local plugin = require("praxo.plugin")
local runtime = require("praxo.runtime")
local sse = require("praxo.sse")
local toolcall = require("praxo.toolcall")
local openai_compat = require("praxo.adapters.openai_compatible")
local anthropic_adapter = require("praxo.adapters.anthropic")
local gemini_adapter = require("praxo.adapters.gemini")
local harmovela_sink = require("praxo.adapters.harmovela_sink")
assert(require("praxo.openai_compatible") == openai_compat)
assert(require("praxo.harmovela_sink") == harmovela_sink)

local function check(condition, message)
  if not condition then error(message) end
end

local call = toolcall.parse_toolcall('{"name":"echo","input":{"text":"hi"}}')
check(call and call.name == "echo" and call.input.text == "hi", "toolcall")
check(toolcall.strip_markup('hello<tool_call name="echo">{"text":"hi"}</tool_call>world') ==
      "helloworld", "toolcall strip")

local schema = json.parse('{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}')
local validation = jsonschema.validate(schema, {})
check(#validation == 1 and validation[1].path == "$.name", "jsonschema")
check(#jsonschema.validate(schema, { name = "ok" }) == 0, "jsonschema valid")
local unicode_schema = json.parse('{"type":"string","minLength":2,"maxLength":2}')
check(#jsonschema.validate(unicode_schema, "你好") == 0, "schema unicode two")
check(#jsonschema.validate(unicode_schema, "你") == 1, "schema unicode one")
local integer_schema = json.parse('{"type":"integer"}')
check(#jsonschema.validate(integer_schema, 2) == 0, "schema integer")
check(#jsonschema.validate(integer_schema, 2.5) == 1, "schema integer fraction")

local manifest = plugin.parse_manifest(
  '{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0",' ..
  '"kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},' ..
  '"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},' ..
  '"health":{},"isolation":"process"}'
)
check(manifest.id == "com.example.echo", "plugin")

local store = runtime.memory_store()
runtime.memory_put(store, "s1", models.memory_record({
  id = "m1", content = "Alpha", created_at = "2026-01-01T00:00:00Z",
}))
runtime.memory_put(store, "s1", models.memory_record({
  id = "m2", content = "ALPHABET", created_at = "2026-01-02T00:00:00Z",
}))
local records = runtime.memory_search(store, "s1", "alpha", 10)
check(#records == 2 and records[1].id == "m2" and records[2].id == "m1", "memory")

local allowlist = runtime.checkpoint_allowlist()
runtime.checkpoint_register(allowlist, "spec.payload")
local data = runtime.checkpoint_marshal(allowlist, "spec.payload", { value = "x" })
check(runtime.checkpoint_unmarshal(allowlist, data).value == "x", "checkpoint")

local checker = runtime.path_checker({
  models.path_grant({ root = "root", access = "readwrite" }),
})
check(runtime.path_check(checker, "root/a.txt", "read").allowed, "policy allow")
check(not runtime.path_check(checker, "root-evil/x.txt", "read").allowed, "policy sibling")
check(not runtime.path_check(checker, "root/../outside/x.txt", "read").allowed, "policy traversal")

local messages = { models.message_text(models.SYSTEM, "sys") }
for index = 0, 9 do
  messages[#messages + 1] = models.message_text(models.USER, "message " .. index)
end
check(runtime.estimate_tokens(messages) == 64, "context estimate")
local output, ok = runtime.compact_context(runtime.context_budget(30, 2), messages)
check(ok, "context compact")
check(runtime.estimate_tokens(output) == 25, "context compact tokens")
check(output[2].content == "[context compacted: 8 older messages omitted]", "context marker")

check(middleware.redact("email a@b.com") == "email [REDACTED:email]", "pii")
local pii_history = {
  messages = { {
    content = "email a@b.com",
    toolCalls = { {
      arguments = { email = "a@b.com", nested = { ssn = "123-45-6789" } },
    } },
  } },
}
local redacted_history = middleware.redact_value(pii_history)
check(redacted_history.messages[1].toolCalls[1].arguments.email == "[REDACTED:email]",
      "pii tool-call email")
check(redacted_history.messages[1].toolCalls[1].arguments.nested.ssn == "[REDACTED:ssn]",
      "pii nested tool-call ssn")
check(pii_history.messages[1].toolCalls[1].arguments.email == "a@b.com",
      "pii input unchanged")
local structured_schema = json.parse(
  '{"type":"object","properties":{"value":{"type":"integer"}},"required":["value"]}'
)
local structured = middleware.structured_output(structured_schema, 0)
local text, code = structured:apply('{"value":1}')
check(text == '{"value":1}' and code == nil, "structured")

local limit = middleware.call_limit(1, 0)
middleware.call_limit_model(limit)
local caught = false
local ok_call = pcall(middleware.call_limit_model, limit)
caught = not ok_call
check(caught, "call limit")

local tool_limit = middleware.call_limit(0, 1)
middleware.call_limit_tool(tool_limit)
check(not pcall(middleware.call_limit_tool, tool_limit), "tool call limit")

local capacity_options = agent.agent_options(agent.static_model("done"))
capacity_options.system_prompt = string.rep("x", 1000)
capacity_options.context = runtime.context_budget(10, 0)
check(not pcall(agent.run_agent, capacity_options, models.session({ id = "s1" }), "go"),
      "capacity fail closed")

local selection = middleware.tool_selection({ "echo" })
local tools = { models.tool_spec({ name = "echo" }), models.tool_spec({ name = "other" }) }
check(#middleware.select_tools(selection, tools) == 1, "tool selection")
local reject_ok = pcall(middleware.check_tool_selected, selection, "other")
check(not reject_ok, "tool selection reject")

local fallback = middleware.fallback_model(function(_request)
  return models.response({ message = models.message_assistant("fallback") })
end)(function(_request) errors.raise("PRIMARY_FAILED", "primary") end)
check(fallback(models.request()).message.content == "fallback", "fallback")

local invocations = 0
local registry = agent.tool_registry()
agent.register_tool(registry, agent.func_tool("echo", "Echo", function(arguments)
  invocations = invocations + 1
  return arguments
end))
local sink = { types = {} }
sink.emit = function(event) sink.types[#sink.types + 1] = event.type end
local next_step = 1
local model = {
  generate = function(_request)
    local steps = {
      { content = "", toolCalls = { { id = "c1", name = "echo", arguments = { text = "hi" } } } },
      { content = "done" },
    }
    local step = steps[next_step]
    next_step = next_step + 1
    local calls = {}
    for _, item in ipairs(step.toolCalls or {}) do
      calls[#calls + 1] = models.tool_call(item)
    end
    return models.response({ message = models.message_assistant(step.content, calls) })
  end,
}
local options = agent.agent_options(model)
options.tools = registry
options.events = sink
local result = agent.run_agent(options, models.session({ id = "s1" }), "go")
check(result.output == "done" and result.steps == 2 and invocations == 1, "agent loop")
check(json.equals(sink.types, { "run.started", "tool.call", "run.completed" }), "agent events")


local function tool_model()
  local next_step = 1
  return {
    generate = function(_request)
      local steps = {
        { content = "", toolCalls = { { id = "c1", name = "echo", arguments = { text = "hi" } } } },
        { content = "done" },
      }
      local step = steps[next_step]
      next_step = next_step + 1
      local calls = {}
      for _, item in ipairs(step.toolCalls or {}) do
        calls[#calls + 1] = models.tool_call(item)
      end
      return models.response({ message = models.message_assistant(step.content, calls) })
    end,
  }
end

local final_arguments_invoked = {}
local final_arguments_registry = agent.tool_registry()
agent.register_tool(final_arguments_registry, agent.func_tool("echo", "Echo", function(arguments)
  final_arguments_invoked[#final_arguments_invoked + 1] = arguments
  return arguments
end))
local final_arguments_actions = {}
local final_arguments_options = agent.agent_options(tool_model())
final_arguments_options.tools = final_arguments_registry
final_arguments_options.policy = function(action)
  final_arguments_actions[#final_arguments_actions + 1] = action
  return { allowed = true, reason = "ok" }
end
final_arguments_options.middleware = {
  { before_tool = function(call)
      call.arguments = { text = "mutated" }
      return call
    end },
}
agent.run_agent(final_arguments_options, models.session({ id = "s1" }), "go")
check(final_arguments_invoked[1].text == "mutated", "lua final arguments effect")
local final_arguments_count = 0
for _, action in ipairs(final_arguments_actions) do
  if action.kind == "tool.invoke" then final_arguments_count = final_arguments_count + 1 end
end
check(final_arguments_count == 2, "lua final arguments reauthorized")

local final_name_invoked = {}
local final_name_registry = agent.tool_registry()
agent.register_tool(final_name_registry, agent.func_tool("other", "Other", function(arguments)
  final_name_invoked[#final_name_invoked + 1] = arguments
  return arguments
end))
local final_name_options = agent.agent_options(tool_model())
final_name_options.tools = final_name_registry
final_name_options.allowed_tools = { "echo", "other" }
final_name_options.middleware = {
  { before_tool = function(call)
      call.name = "other"
      return call
    end },
}
agent.run_agent(final_name_options, models.session({ id = "s1" }), "go")
check(#final_name_invoked == 1, "lua final name uses final tool")

local denied_name_options = agent.agent_options(tool_model())
denied_name_options.tools = final_name_registry
denied_name_options.allowed_tools = { "echo" }
denied_name_options.middleware = {
  { before_tool = function(call)
      call.name = "other"
      return call
    end },
}
local ok_name, err_name = pcall(agent.run_agent, denied_name_options, models.session({ id = "s1" }), "go")
check(not ok_name and errors.code(err_name) == "AGENT_TOOL_NOT_ALLOWED", "lua final name allowlist")

local unchanged_actions = {}
local unchanged_options = agent.agent_options(tool_model())
unchanged_options.tools = final_arguments_registry
unchanged_options.policy = function(action)
  unchanged_actions[#unchanged_actions + 1] = action
  return { allowed = true, reason = "ok" }
end
unchanged_options.middleware = { {} }
agent.run_agent(unchanged_options, models.session({ id = "s1" }), "go")
local unchanged_count = 0
for _, action in ipairs(unchanged_actions) do
  if action.kind == "tool.invoke" then unchanged_count = unchanged_count + 1 end
end
check(unchanged_count == 1, "lua unchanged single authorization")

local initial_calls = 0
local initial_options = agent.agent_options(tool_model())
initial_options.tools = final_arguments_registry
initial_options.policy = function(action)
  return { allowed = action.kind ~= "tool.invoke", reason = "blocked" }
end
initial_options.middleware = {
  { before_tool = function(call)
      initial_calls = initial_calls + 1
      return call
    end },
}
local ok_initial, err_initial = pcall(agent.run_agent, initial_options, models.session({ id = "s1" }), "go")
check(not ok_initial and errors.code(err_initial) == "AGENT_POLICY_DENIED" and initial_calls == 0,
      "lua initial denial prevents middleware")

local startup_calls = {}
local startup_options = agent.agent_options(agent.static_model("done"))
startup_options.middleware = {
  { before_run = function(_state) startup_calls[#startup_calls + 1] = "first.before" end,
    after_run = function(_result, _error) startup_calls[#startup_calls + 1] = "first.after" end },
  { before_run = function(_state) errors.raise("STARTUP_FAILED", "startup failed") end,
    after_run = function(_result, _error) startup_calls[#startup_calls + 1] = "second.after" end },
}
local ok_startup, err_startup = pcall(agent.run_agent, startup_options, models.session({ id = "s1" }), "go")
check(not ok_startup and errors.code(err_startup) == "STARTUP_FAILED", "lua startup failure")
check(json.equals(startup_calls, { "first.before", "first.after", "second.after" }), "lua startup cleanup")

local continue_calls = {}
local continue_model = { generate = function(_request) errors.raise("RUN_FAILED", "run failed") end }
local continue_options = agent.agent_options(continue_model)
continue_options.middleware = {
  { after_run = function(_result, _error)
      continue_calls[#continue_calls + 1] = "first.after"
      errors.raise("CLEANUP_FAILED", "cleanup failed")
    end },
  { after_run = function(_result, _error) continue_calls[#continue_calls + 1] = "second.after" end },
}
local ok_continue, err_continue = pcall(agent.run_agent, continue_options, models.session({ id = "s1" }), "go")
check(not ok_continue and errors.code(err_continue) == "RUN_FAILED", "lua after-run preserves run error")
check(json.equals(continue_calls, { "first.after", "second.after" }), "lua after-run continues")

local cleanup_calls = {}
local cleanup_options = agent.agent_options(agent.static_model("done"))
cleanup_options.middleware = {
  { after_run = function(_result, _error)
      cleanup_calls[#cleanup_calls + 1] = "first.after"
      errors.raise("CLEANUP_FAILED", "cleanup failed")
    end },
  { after_run = function(_result, _error) cleanup_calls[#cleanup_calls + 1] = "second.after" end },
}
local ok_cleanup, err_cleanup = pcall(agent.run_agent, cleanup_options, models.session({ id = "s1" }), "go")
check(not ok_cleanup and errors.code(err_cleanup) == "CLEANUP_FAILED", "lua cleanup fail closed")
check(json.equals(cleanup_calls, { "first.after", "second.after" }), "lua cleanup continues")

local sse_complete = sse.parse('data: {"choices":[{"delta":{"content":"hi"}}]}\n\ndata: [DONE]\n\n')
check(sse_complete == "hi", "lua sse complete")
local sse_truncated, sse_truncated_code = sse.parse('data: {"choices":[{"delta":{"content":"hi"}}]}\n\n')
check(sse_truncated == nil and sse_truncated_code == "MODEL_STREAM", "lua sse truncated")
local sse_half, sse_half_code = sse.parse('data: {"choices"\n\n')
check(sse_half == nil and sse_half_code == "MODEL_STREAM", "lua sse half packet")

local first_limit = middleware.call_limit(1, 0)
local second_limit = middleware.call_limit(1, 0)
middleware.call_limit_model(first_limit)
middleware.call_limit_model(second_limit)
check(not pcall(middleware.call_limit_model, first_limit), "lua call limit run a")
check(second_limit.models == 1, "lua call limit isolated run")

local cancel_flag = false
local cancel_model = {
  generate = function(_request)
    cancel_flag = true
    return models.response({ message = models.message_assistant("done") })
  end,
}
local cancel_options = agent.agent_options(cancel_model)
cancel_options.cancellation = function() return cancel_flag end
local cancel_sink = { types = {} }
cancel_sink.emit = function(event) cancel_sink.types[#cancel_sink.types + 1] = event.type end
cancel_options.events = cancel_sink
local cancel_ok, cancel_error = pcall(agent.run_agent, cancel_options, models.session({ id = "s1" }), "go")
check(not cancel_ok and errors.code(cancel_error) == "AGENT_CANCELLED", "lua model cancellation")
check(json.equals(cancel_sink.types, { "run.started", "run.failed" }),
      "lua model cancellation events")

local tool_cancel_flag = false
local tool_cancel_registry = agent.tool_registry()
agent.register_tool(tool_cancel_registry, agent.func_tool("wait", "wait", function(_arguments)
  tool_cancel_flag = true
  return "ok"
end))
local tool_cancel_model = {
  generate = function(request)
    if #request.messages == 1 then
      return models.response({ message = models.message_assistant("", {
        models.tool_call({ id = "c1", name = "wait", arguments = {} }),
      }) })
    end
    return models.response({ message = models.message_assistant("done") })
  end,
}
local tool_cancel_options = agent.agent_options(tool_cancel_model)
tool_cancel_options.tools = tool_cancel_registry
tool_cancel_options.cancellation = function() return tool_cancel_flag end
local tool_cancel_sink = { types = {} }
tool_cancel_sink.emit = function(event) tool_cancel_sink.types[#tool_cancel_sink.types + 1] = event.type end
tool_cancel_options.events = tool_cancel_sink
local tool_cancel_ok, tool_cancel_error = pcall(
  agent.run_agent, tool_cancel_options, models.session({ id = "s1" }), "go"
)
check(not tool_cancel_ok and errors.code(tool_cancel_error) == "AGENT_CANCELLED",
      "lua tool cancellation")
check(json.equals(tool_cancel_sink.types, { "run.started", "tool.call", "run.failed" }),
      "lua tool cancellation events")

local stream_parts = {}
local stream_options = agent.agent_options(agent.static_model("done"))
stream_options.on_stream = function(part)
  stream_parts[#stream_parts + 1] = part.kind
  if part.kind == "messages" then error("stream failed") end
end
local stream_sink = { types = {} }
stream_sink.emit = function(event) stream_sink.types[#stream_sink.types + 1] = event.type end
stream_options.events = stream_sink
local stream_ok, stream_error = pcall(agent.run_agent, stream_options, models.session({ id = "s1" }), "go")
check(not stream_ok and errors.code(stream_error) == "STREAM_ERROR", "lua stream failure")
check(json.equals(stream_parts, { "values", "messages" }), "lua stream parts")
check(json.equals(stream_sink.types, { "run.started", "run.failed" }),
      "lua stream failure events")

local parallel_started = 0
local parallel_release = false
local parallel_registry = agent.tool_registry()
for _, name in ipairs({ "a", "b" }) do
  agent.register_tool(parallel_registry, agent.func_tool(name, name, function(_arguments)
    return name
  end))
end
local parallel_order = {}
local parallel_model = {
  generate = function(request)
    if #request.messages == 1 then
      return models.response({ message = models.message_assistant("", {
        models.tool_call({ id = "c1", name = "a", arguments = {} }),
        models.tool_call({ id = "c2", name = "b", arguments = {} }),
      }) })
    end
    for _, message in ipairs(request.messages) do
      if message.role == models.TOOL then
        parallel_order[#parallel_order + 1] = message.tool_id
      end
    end
    return models.response({ message = models.message_assistant("done") })
  end,
}
local parallel_options = agent.agent_options(parallel_model)
parallel_options.tools = parallel_registry
parallel_options.max_parallel_tools = 2
parallel_options.batch_invoke = function(prepared, max_parallel)
  check(max_parallel == 2, "lua parallel limit")
  local coroutines = {}
  for index, entry in ipairs(prepared) do
    coroutines[index] = coroutine.create(function()
      parallel_started = parallel_started + 1
      coroutine.yield()
      while not parallel_release do coroutine.yield() end
      return entry.tool.invoke(entry.call.arguments)
    end)
  end
  for _, co in ipairs(coroutines) do assert(coroutine.resume(co)) end
  check(parallel_started == 2, "lua parallel started")
  parallel_release = true
  local results = {}
  for index, co in ipairs(coroutines) do
    local ok, value = coroutine.resume(co)
    check(ok, "lua parallel resume")
    results[index] = value
  end
  return results
end
local parallel_result = agent.run_agent(parallel_options, models.session({ id = "s1" }), "go")
check(parallel_result.output == "done", "lua parallel result")
check(json.equals(parallel_order, { "c1", "c2" }), "lua parallel order")

local hitl_calls = 0
local hitl_registry = agent.tool_registry()
agent.register_tool(hitl_registry, agent.func_tool("echo", "Echo", function(arguments)
  hitl_calls = hitl_calls + 1
  return arguments
end))
local function hitl_model()
  local step = 0
  return {
    generate = function(_request)
      if step == 0 then
        step = 1
        return models.response({
          message = models.message_assistant("", {
            models.tool_call({ id = "c1", name = "echo", arguments = { value = "original" } }),
          }),
        })
      end
      return models.response({ message = models.message_assistant("done") })
    end,
  }
end
local hitl_options = agent.agent_options(hitl_model())
hitl_options.tools = hitl_registry
hitl_options.interrupt_on = { "echo" }
hitl_options.on_interrupt_decision = function(_interrupt)
  return models.interrupt_decision({ action = models.INTERRUPT_APPROVE })
end
local hitl_result = agent.run_agent(hitl_options, models.session({ id = "s1" }), "go")
check(hitl_result.output == "done" and hitl_calls == 1, "lua hitl approve")

hitl_calls = 0
local hitl_actions = {}
hitl_options = agent.agent_options(hitl_model())
hitl_options.tools = hitl_registry
hitl_options.interrupt_on = { "echo" }
hitl_options.policy = function(action)
  if action.kind == "tool.invoke" then hitl_actions[#hitl_actions + 1] = action end
  return models.decision({ allowed = true })
end
hitl_options.on_interrupt_decision = function(_interrupt)
  return models.interrupt_decision({
    action = models.INTERRUPT_EDIT, arguments = { value = "edited" },
  })
end
agent.run_agent(hitl_options, models.session({ id = "s1" }), "go")
check(hitl_calls == 1 and #hitl_actions == 2, "lua hitl edit reauthorizes")

hitl_calls = 0
hitl_options = agent.agent_options(hitl_model())
hitl_options.tools = hitl_registry
hitl_options.interrupt_on = { "echo" }
hitl_options.on_interrupt_decision = function(_interrupt)
  return models.interrupt_decision({ action = models.INTERRUPT_REJECT, reason = "no" })
end
local hitl_ok, hitl_error = pcall(function()
  agent.run_agent(hitl_options, models.session({ id = "s1" }), "go")
end)
check(not hitl_ok and errors.code(hitl_error) == "AGENT_APPROVAL_DENIED" and hitl_calls == 0,
      "lua hitl reject")

hitl_options = agent.agent_options(hitl_model())
hitl_options.tools = hitl_registry
hitl_options.interrupt_on = { "echo" }
hitl_ok, hitl_error = pcall(function()
  agent.run_agent(hitl_options, models.session({ id = "s1" }), "go")
end)
check(not hitl_ok and errors.code(hitl_error) == "AGENT_INTERRUPT_UNHANDLED",
      "lua hitl unhandled")


local captured = nil
local adapter = openai_compat.new({
  base_url = "http://example.test/v1",
  model = "test-model",
  transport = function(payload)
    captured = payload
    return {
      choices = { {
        message = {
          content = "hello",
          tool_calls = { {
            id = "c1",
            ["function"] = { name = "echo", arguments = '{"text":"hi"}' },
          } },
        },
        finish_reason = "tool_calls",
      } },
      usage = { prompt_tokens = 3, completion_tokens = 2 },
    }
  end,
})
local adapter_request = models.request({
  messages = { models.message_text(models.USER, "hi") },
  tools = { models.tool_spec({ name = "echo", description = "echo" }) },
})
local adapter_response = adapter.generate(adapter_request)
check(adapter_response.message.content == "hello", "adapter content")
check(adapter_response.message.tool_calls[1].name == "echo", "adapter tool")
check(adapter_response.message.tool_calls[1].arguments.text == "hi", "adapter args")
check(adapter_response.usage.input_tokens == 3 and adapter_response.usage.output_tokens == 2, "adapter usage")
check(captured.model == "test-model", "adapter model")
check(captured.messages[1].role == "user", "adapter role")
check(captured.tools[1]["function"].name == "echo", "adapter tool spec")

local harmovela_captured = nil
local harmovela = harmovela_sink.new({
  base_url = "http://example.test/aep/api/",
  clock = function() return 1700000000, 123456789 end,
  transport = function(path, body, headers)
    harmovela_captured = { path = path, body = body, headers = headers }
    return { status = 200, body = "" }
  end,
})
local harmovela_event = models.event({
  type = "tool.call", session_id = "s1", run_id = "run-123", data = { name = "echo" },
})
check(harmovela.emit(harmovela_event) == nil, "harmovela success")
check(harmovela_captured.path == "/events", "harmovela path")
check(harmovela_captured.headers["content-type"] == "application/json",
      "harmovela content type")
local harmovela_envelope = json.parse(harmovela_captured.body)
check(harmovela_envelope.spec_version == "0.2", "harmovela spec version")
check(harmovela_envelope.id == "run-123-1700000000123456789", "harmovela id")
check(harmovela_envelope.type == "tool.call", "harmovela type")
check(harmovela_envelope.source == "praxo-core", "harmovela source")
check(harmovela_envelope.created_at == "2023-11-14T22:13:20.123456789Z",
      "harmovela created at")
check(json.equals(harmovela_envelope.payload, {
  name = "echo", session_id = "s1", run_id = "run-123",
}), "harmovela payload")

local harmovela_failed = harmovela_sink.new({
  base_url = "http://example.test/aep/api",
  clock = function() return 1700000000, 123456789 end,
  transport = function(_path, _body, _headers)
    return { status = 500, body = "boom" }
  end,
})
local harmovela_ok, harmovela_error = pcall(function()
  harmovela_failed.emit(harmovela_event)
end)
check(not harmovela_ok and errors.code(harmovela_error) == "HARMOVELA_HTTP",
      "harmovela non-2xx code")
check(harmovela_error.message:find("500", 1, true) and
      harmovela_error.message:find("boom", 1, true), "harmovela non-2xx body")

local anthropic_payload = nil
local anthropic = anthropic_adapter.new({
  model = "claude-test",
  api_key = "ak",
  transport = function(payload)
    anthropic_payload = payload
    return {
      content = {
        { type = "text", text = "hello" },
        { type = "tool_use", id = "tool-1", name = "echo", input = { text = "hi" } },
      },
      stop_reason = "end_turn",
      usage = { input_tokens = 3, output_tokens = 4, cache_read_input_tokens = 2 },
    }
  end,
})
local anthropic_response = anthropic.generate(models.request({
  messages = {
    models.message_text(models.SYSTEM, "be brief"),
    models.message_text(models.USER, "hi"),
  },
  tools = { models.tool_spec({ name = "echo", description = "Echo", parameters = { type = "object" } }) },
}))
check(anthropic_response.message.content == "hello", "anthropic content")
check(anthropic_response.message.tool_calls[1].id == "tool-1", "anthropic call id")
check(anthropic_response.message.tool_calls[1].arguments.text == "hi", "anthropic args")
check(anthropic_payload.system == "be brief", "anthropic system")
check(anthropic_payload.tools[1].input_schema.type == "object", "anthropic tools")

local gemini_payload = nil
local gemini = gemini_adapter.new({
  model = "gemini-test",
  api_key = "gk",
  transport = function(payload)
    gemini_payload = payload
    return {
      candidates = {{
        content = { parts = {
          { text = "hello" },
          { functionCall = { name = "echo", args = { text = "hi" } } },
        } },
        finishReason = "STOP",
      }},
      usageMetadata = { promptTokenCount = 3, candidatesTokenCount = 4 },
    }
  end,
})
local gemini_response = gemini.generate(models.request({
  messages = {
    models.message_text(models.SYSTEM, "be brief"),
    models.message_text(models.USER, "hi"),
  },
  tools = { models.tool_spec({ name = "echo", description = "Echo", parameters = { type = "object" } }) },
}))
check(gemini_response.message.content == "hello", "gemini content")
check(gemini_response.message.tool_calls[1].name == "echo", "gemini call name")
check(gemini_payload.system_instruction.parts[1].text == "be brief", "gemini system")
check(gemini_payload.toolConfig.functionCallingConfig.mode == "AUTO", "gemini tool mode")

print("lua core tests passed")
