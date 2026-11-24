local script_dir = (arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]*$")) or "."
package.path = table.concat({
  script_dir .. "/../../?.lua",
  script_dir .. "/../../?/init.lua",
  "language/lua/?.lua",
  "language/lua/?/init.lua",
  "./?.lua",
  package.path,
}, ";")

local agent = require("praxo.agent")
local errors = require("praxo.errors")
local json = require("praxo.json")
local models = require("praxo.models")

local M = {}

local function engagement_fixture(show_id)
  if show_id ~= "show-100" then
    return nil
  end
  return {
    show_id = "show-100",
    viewers = 1200,
    peak_segment = "opening",
    likes = 80,
    shares = 12,
    source = "engagement_fixture",
  }
end

local function fixture_model(event)
  return {
    generate = function(request)
      local tool_messages = {}
      for _, message in ipairs(request.messages or {}) do
        if message.role == models.TOOL then
          tool_messages[#tool_messages + 1] = message
        end
      end
      if #tool_messages == 0 then
        return models.response({
          message = models.message_assistant("", {
            models.tool_call({
              id = "engagement-1",
              name = "read_engagement",
              arguments = { show_id = event.show_id },
            }),
          }),
        })
      end
      if #tool_messages == 1 then
        return models.response({
          message = models.message_assistant("", {
            models.tool_call({
              id = "order-1",
              name = "draft_order",
              arguments = { show_id = event.show_id, action = "draft_order" },
            }),
          }),
        })
      end
      local engagement = json.parse(tool_messages[1].content)
      local order = json.parse(tool_messages[2].content)
      return models.response({
        message = models.message_assistant(json.encode({
          engagement = engagement,
          order = order,
          stream_controls = 0,
          coupons = 0,
        })),
      })
    end,
  }
end

function M.handle_event(event, simulate_failure)
  local reads = 0
  local drafts = 0
  local registry = agent.tool_registry()
  agent.register_tool(registry, agent.func_tool(
    "read_engagement", "Replay fixed synthetic engagement events; no profiling.",
    function(arguments)
      reads = reads + 1
      if simulate_failure then
        error("simulated engagement index unavailable")
      end
      local show = engagement_fixture(arguments.show_id)
      if not show then
        error("show not found")
      end
      return show
    end
  ))
  agent.register_tool(registry, agent.func_tool(
    "draft_order", "Draft a review-only presentation order; never controls a stream.",
    function(arguments)
      if arguments.show_id ~= "show-100" then
        error("show not found")
      end
      if arguments.action ~= "draft_order" then
        error("unsupported draft action")
      end
      drafts = drafts + 1
      return {
        order_id = "show-order-100",
        show_id = "show-100",
        action = "draft_order",
        order = { "segment-1", "segment-2" },
        status = "draft_only",
        review = "review_required",
        stream_controls = 0,
        coupons = 0,
      }
    end
  ))

  local options = agent.agent_options(fixture_model(event))
  options.tools = registry
  options.allowed_tools = { "read_engagement", "draft_order" }
  options.max_steps = 4
  options.policy = function(action)
    if action.kind == "model.generate" then
      return { allowed = true, reason = "fixture model" }
    end
    if action.kind ~= "tool.invoke" then
      return { allowed = false, reason = "unsupported action" }
    end
    if (action.arguments or {}).show_id ~= "show-100" then
      return { allowed = false, reason = "show outside direction scope" }
    end
    if action.tool_name == "read_engagement" then
      return { allowed = true, reason = "read-only engagement fixture" }
    end
    if action.tool_name == "draft_order" then
      return {
        allowed = (action.arguments or {}).action == "draft_order",
        reason = "only a review-only presentation order is permitted",
      }
    end
    return { allowed = false, reason = "unsupported tool" }
  end

  local ok, result = pcall(agent.run_agent, options,
    models.session({ id = "live-show" }), event.text or "Draft a presentation order.")
  if not ok then
    return nil, reads, drafts, errors.code(result)
  end
  return result.output, reads, drafts, nil
end

function M.run_tests()
  local output, reads, drafts, code = M.handle_event({
    show_id = "show-100", type = "engagement",
    text = "Replay fixed engagement and draft a review-only order.",
  })
  assert(code == nil, "success failed: " .. tostring(code))
  assert(reads == 1 and drafts == 1, "success counts")
  local report = json.parse(output)
  assert(report.engagement.show_id == "show-100", "show citation")
  assert(report.engagement.viewers == 1200, "viewers")
  assert(report.order.status == "draft_only", "order status")
  assert(report.order.review == "review_required", "order review")
  assert(#report.order.order == 2, "order segments")
  assert(report.order.stream_controls == 0 and report.stream_controls == 0, "no stream control")
  assert(report.coupons == 0, "no coupons")

  local _, deny_reads, deny_drafts, deny_code = M.handle_event({
    show_id = "show-200", type = "engagement",
    text = "Draft the out-of-scope show.",
  })
  assert(deny_code == "AGENT_POLICY_DENIED", "deny code")
  assert(deny_reads == 0 and deny_drafts == 0, "deny counts")

  local _, fail_reads, fail_drafts, fail_code = M.handle_event({
    show_id = "show-100", type = "engagement",
    text = "Replay fixed engagement and draft an order.",
  }, true)
  assert(fail_code ~= nil, "failure code")
  assert(fail_reads == 1 and fail_drafts == 0, "failure counts")

  print("Lua live-show tutorial: all checks passed")
end

if arg and arg[1] == "--test" then
  M.run_tests()
  return M
end

local simulate_failure = false
for i = 1, #arg do
  if arg[i] == "--simulate-failure" then
    simulate_failure = true
  end
end
local show_id = arg and arg[1]
if not show_id or show_id == "--simulate-failure" then
  show_id = "show-100"
end
local event = {
  show_id = show_id,
  type = "engagement",
  text = "Replay fixed engagement and draft a review-only order.",
}
local output, reads, drafts, code = M.handle_event(event, simulate_failure)
if code then
  io.stderr:write(string.format("live show failed: reads=%d drafts=%d; %s\n", reads, drafts, tostring(code)))
  os.exit(1)
end
print(output)

return M
