package.path = table.concat({ "sdk/lua/?.lua", "sdk/lua/?/init.lua", "./?.lua", package.path }, ";")

local agent = require("praxo.agent")
local errors = require("praxo.errors")
local json = require("praxo.json")
local jsonschema = require("praxo.jsonschema")
local middleware = require("praxo.middleware")
local models = require("praxo.models")
local plugin = require("praxo.plugin")
local runtime = require("praxo.runtime")
local toolcall = require("praxo.toolcall")

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

print("lua core tests passed")
