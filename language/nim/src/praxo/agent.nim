import std/json
import std/options
import std/strutils
import std/times

import ./errors
import ./jsonutil
import ./models
import ./middleware
import ./runtime

proc echoInvoke(arguments: JsonNode): JsonNode =
  return arguments

type
  Tool* = ref object
    name*: string
    description*: string
    calls*: int
    invoke*: proc(arguments: JsonNode): JsonNode {.closure.}

  Model* = ref object
    mode*: string
    script*: seq[Response]
    index*: int
    content*: string
    primary*: Model
    fallback*: Model
    invoke*: proc(request: Request): Response {.closure.}

  AgentOptions* = object
    model*: Model
    tools*: seq[Tool]
    toolSelection*: Option[ToolSelection]
    events*: Sink
    systemPrompt*: string
    maxSteps*: int
    maxTokens*: int
    sessionId*: string

proc newTool*(name: string, description: string,
              invoke: proc(arguments: JsonNode): JsonNode {.closure.} = echoInvoke): Tool =
  return Tool(name: name, description: description, invoke: invoke)

proc call*(tool: Tool, arguments: JsonNode): JsonNode =
  inc tool.calls
  if tool.invoke.isNil:
    return arguments
  return tool.invoke(arguments)

proc generate*(model: Model, request: Request): Response =
  if model.mode == "callback":
    if model.invoke.isNil:
      raisePraxo("MODEL_ERROR", "model callback is not configured")
    return model.invoke(request)
  if model.mode == "fallback":
    if not model.primary.isNil:
      try:
        return model.primary.generate(request)
      except CatchableError:
        if not model.fallback.isNil:
          return model.fallback.generate(request)
        raise
    raisePraxo("MODEL_ERROR", "fallback model is not configured")
  if model.mode == "static":
    return newResponse(newMessageAssistant(model.content))
  if model.mode == "failing":
    raisePraxo("MODEL_ERROR", "primary model failed")
  if model.index >= model.script.len:
    raisePraxo("MODEL_ERROR", "script exhausted")
  result = model.script[model.index]
  inc model.index

proc scriptedModel*(steps: seq[Response]): Model =
  return Model(mode: "scripted", script: steps)

proc callbackModel*(invoke: proc(request: Request): Response {.closure.}): Model =
  return Model(mode: "callback", invoke: invoke)

proc staticModel*(content: string): Model =
  return Model(mode: "static", content: content)

proc failingModel*(): Model =
  return Model(mode: "failing")

proc fallbackModel*(primary: Model, fallback: Model): Model =
  return Model(mode: "fallback", primary: primary, fallback: fallback)

proc newAgentOptions*(model: Model): AgentOptions =
  return AgentOptions(model: model, maxSteps: 8, sessionId: "s1")

proc toolSpecs(tools: seq[Tool]): seq[ToolSpec] =
  var specs: seq[ToolSpec] = @[]
  for tool in tools:
    specs.add(newToolSpec(tool.name, tool.description))
  return specs

proc findToolIndex(tools: seq[Tool], name: string): int =
  for index, tool in tools:
    if tool.name == name:
      return index
  return -1

proc emitEvent(events: Sink, kind: string, sessionId: string, runId: string, data: JsonNode) =
  if events.isNil:
    return
  events.emit(newEvent(kind, sessionId, runId, data))

proc runAgent*(options: AgentOptions, session: Session, prompt: string): RunResult =
  if options.model.isNil:
    raisePraxo("MODEL_ERROR", "model is not configured")
  let runId = "run-" & $getTime().toUnix()
  var messages: seq[Message] = @[]
  messages.add(session.messages)
  if options.systemPrompt.len > 0:
    messages.insert(newMessage(ROLE_SYSTEM, options.systemPrompt), 0)
  messages.add(newMessage(ROLE_USER, prompt))
  emitEvent(options.events, "run.started", session.id, runId, newJNull())
  try:
    let maxSteps = if options.maxSteps > 0: options.maxSteps else: 8
    var total = newUsage()
    for step in 1 .. maxSteps:
      var specs = toolSpecs(options.tools)
      if options.toolSelection.isSome:
        specs = selectTools(options.toolSelection.get(), specs)
      let response = options.model.generate(newRequest(messages, specs))
      total = addUsage(total, response.usage)
      if options.maxTokens > 0 and total.inputTokens + total.outputTokens > options.maxTokens:
        raisePraxo("AGENT_MAX_TOKENS", "token budget exceeded")
      messages.add(response.message)
      if response.message.toolCalls.len == 0:
        emitEvent(options.events, "run.completed", session.id, runId, newJNull())
        return newRunResult(runId, response.message.content, step, total)
      for call in response.message.toolCalls:
        let index = findToolIndex(options.tools, call.name)
        if index < 0:
          raisePraxo("TOOL_NOT_FOUND", "tool not found: " & call.name)
        if options.toolSelection.isSome:
          checkToolSelected(options.toolSelection.get(), call.name)
        var data = newJObject()
        data["name"] = %call.name
        data["arguments"] = if call.arguments.isNil: newJObject() else: call.arguments
        emitEvent(options.events, "tool.call", session.id, runId, data)
        let value = options.tools[index].call(call.arguments)
        messages.add(newMessageTool(encodeJson(value), call.id))
    raisePraxo("AGENT_MAX_STEPS", "maximum steps exceeded")
  except CatchableError as error:
    var data = newJObject()
    data["error"] = %error.msg
    emitEvent(options.events, "run.failed", session.id, runId, data)
    raise
