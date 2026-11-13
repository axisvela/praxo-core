local errors = require("praxo.errors")

local M = {}

function M.subagent_request(parent_session_id, agent_id, prompt, opts)
  opts = opts or {}
  return {
    parent_session_id = tostring(parent_session_id),
    agent_id = tostring(agent_id),
    prompt = tostring(prompt),
    context = opts.context or {},
    mode = opts.mode == "fork" and "fork" or "isolated",
    history = opts.history or {},
  }
end

function M.subagent_result(opts)
  opts = opts or {}
  return {
    task_id = opts.task_id or "",
    agent_id = opts.agent_id or "",
    output = opts.output or "",
    usage = opts.usage,
  }
end

function M.subagent_run(runner, request)
  if type(runner) ~= "function" then
    errors.raise("SUBAGENT_INVALID", "agent: subagent runner is required")
  end
  if request.parent_session_id == "" or request.agent_id == "" then
    errors.raise("SUBAGENT_INVALID",
      "agent: subagent parent session and agent id are required")
  end
  local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local task = {
    id = string.format("subagent-%d-%d", os.time(),
      math.random(0, 999999)),
    parent_session_id = request.parent_session_id,
    agent_id = request.agent_id,
    mode = request.mode,
    status = "running",
    output = "",
    error = "",
    created_at = now,
    updated_at = now,
  }
  local ok, result = pcall(runner, request)
  if ok then
    task.status = "completed"
    task.output = result.output or ""
  else
    task.status = "failed"
    task.error = tostring(result)
  end
  task.updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  return task
end

return M
