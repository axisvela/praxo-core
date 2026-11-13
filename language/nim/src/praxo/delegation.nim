import std/[strformat, times]

import ./errors

type
  SubagentRequest* = object
    parentSessionId*: string
    agentId*: string
    prompt*: string
    mode*: string

  SubagentResult* = object
    taskId*: string
    agentId*: string
    output*: string

  SubagentTask* = object
    id*: string
    parentSessionId*: string
    agentId*: string
    mode*: string
    status*: string
    output*: string
    error*: string
    createdAt*: string
    updatedAt*: string

  SubagentRunner* = proc(request: SubagentRequest): SubagentResult {.closure.}

  SubagentClock* = proc(): Time {.closure.}

proc rfc3339Nano(at: Time): string =
  let value = at.utc
  result = &"{value.year:04}-{ord(value.month):02}-{value.monthday:02}T" &
           &"{value.hour:02}:{value.minute:02}:{value.second:02}." &
           &"{value.nanosecond:09}Z"

proc newSubagentRequest*(parentSessionId: string, agentId: string,
                         prompt: string,
                         mode: string = "isolated"): SubagentRequest =
  SubagentRequest(
    parentSessionId: parentSessionId,
    agentId: agentId,
    prompt: prompt,
    mode: if mode.len > 0: mode else: "isolated",
  )

proc newSubagentResult*(taskId: string = "", agentId: string = "",
                        output: string = ""): SubagentResult =
  SubagentResult(taskId: taskId, agentId: agentId, output: output)

proc subagentRun*(runner: SubagentRunner, request: SubagentRequest,
                  clock: SubagentClock = nil): SubagentTask =
  if runner == nil:
    raisePraxo("SUBAGENT_INVALID", "agent: subagent runner is required")
  if request.parentSessionId.len == 0 or request.agentId.len == 0:
    raisePraxo("SUBAGENT_INVALID",
      "agent: subagent parent session and agent id are required")
  let at = if clock != nil: clock() else: getTime()
  let stamp = rfc3339Nano(at)
  var task = SubagentTask(
    id: "subagent",
    parentSessionId: request.parentSessionId,
    agentId: request.agentId,
    mode: if request.mode == "fork": "fork" else: "isolated",
    status: "running",
    output: "",
    error: "",
    createdAt: stamp,
    updatedAt: stamp,
  )
  try:
    let result = runner(request)
    task.status = "completed"
    task.output = result.output
  except PraxoError as error:
    task.status = "failed"
    task.error = errorCode(error)
  except CatchableError:
    task.status = "failed"
    task.error = "SUBAGENT_ERROR"
  let completedAt = if clock != nil: clock() else: getTime()
  task.updatedAt = rfc3339Nano(completedAt)
  return task
