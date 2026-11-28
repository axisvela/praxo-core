import std/json
import std/options
import std/strutils
import std/times

import ./errors
import ./hitl
import ./jsonutil
import ./models
import ./middleware
import ./runtime

proc echoInvoke(arguments: JsonNode): JsonNode =
  return arguments

type
  Policy* = proc(action: Action): Decision {.closure.}

  ToolMiddleware* = proc(runId: string, sessionId: string, call: var ToolCall) {.closure.}

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
    stream*: proc(request: Request, onDelta: proc(delta: string)): Response {.closure.}

  AgentOptions* = object
    model*: Model
    tools*: seq[Tool]
    toolSelection*: Option[ToolSelection]
    events*: Sink
    systemPrompt*: string
    maxSteps*: int
    maxTokens*: int
    sessionId*: string
    pii*: bool
    structuredOutput*: Option[StructuredOutput]
    modelCallLimit*: int
    toolCallLimit*: int
    policy*: Policy
    allowedTools*: seq[string]
    middleware*: seq[ToolMiddleware]
    onDelta*: proc(delta: string) {.closure.}
    interruptOn*: seq[string]
    onInterruptDecision*: InterruptHandler
    onInterrupt*: InterruptApproval
    requirePolicy*: bool
    requireToolScope*: bool

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

proc generateStream*(model: Model, request: Request,
                     onDelta: proc(delta: string)): Response =
  if not model.stream.isNil:
    return model.stream(request, onDelta)
  result = model.generate(request)
  if result.message.content.len > 0:
    onDelta(result.message.content)

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

proc copyJson(value: JsonNode): JsonNode =
  if value.isNil:
    return nil
  return parseJson(encodeJson(value))

proc toolAllowed(options: AgentOptions, name: string): bool =
  return options.allowedTools.len == 0 or name in options.allowedTools

proc authorize(options: AgentOptions, action: Action) =
  if options.policy.isNil:
    return
  let decision = options.policy(action)
  if decision.allowed:
    return
  var message = "agent: " & action.kind & " denied"
  if decision.reason.len > 0:
    message = message & ": " & decision.reason
  raisePraxo("AGENT_POLICY_DENIED", message)

proc applyInterrupt(options: AgentOptions, call: var ToolCall, runId: string,
                    sessionId: string): tuple[skip: bool, response: string] =
  if call.name notin options.interruptOn:
    return (false, "")
  if options.onInterruptDecision.isNil and options.onInterrupt.isNil:
    raisePraxo("AGENT_INTERRUPT_UNHANDLED",
               "agent: approval handler not configured: " & call.name)
  var data = newJObject()
  data["name"] = %call.name
  data["arguments"] = if call.arguments.isNil: newJObject() else: call.arguments
  emitEvent(options.events, "tool.interrupt", sessionId, runId, data)
  let interrupt = newInterrupt(runId, sessionId, call)
  if not options.onInterruptDecision.isNil:
    let decision = options.onInterruptDecision(interrupt)
    case decision.action
    of INTERRUPT_APPROVE:
      return (false, "")
    of INTERRUPT_EDIT:
      if decision.arguments.isNil:
        raisePraxo("AGENT_INTERRUPT_DECISION_INVALID",
                   "agent: edit requires arguments")
      call.arguments = decision.arguments
      return (false, "")
    of INTERRUPT_REJECT:
      raisePraxo("AGENT_APPROVAL_DENIED",
                 "agent: tool call denied by approval: " & call.name & ": " &
                 decision.reason)
    of INTERRUPT_RESPOND:
      return (true, decision.response)
    else:
      raisePraxo("AGENT_INTERRUPT_DECISION_INVALID",
                 "agent: invalid interrupt decision: " & decision.action)
  if not options.onInterrupt(interrupt):
    raisePraxo("AGENT_APPROVAL_DENIED",
               "agent: tool call denied by approval: " & call.name)
  return (false, "")

var runSequence = 0

proc runAgent*(options: AgentOptions, session: Session, prompt: string): RunResult =
  if options.requirePolicy and options.policy.isNil:
    raisePraxo("AGENT_INVALID_OPTIONS", "agent: require policy: policy is required")
  if options.requireToolScope and options.allowedTools.len == 0:
    raisePraxo("AGENT_INVALID_OPTIONS", "agent: require tool scope: allowedTools must not be empty")
  if options.model.isNil:
    raisePraxo("MODEL_ERROR", "model is not configured")
  let now = getTime()
  inc runSequence
  let runId = "run-" & $now.toUnix() & "-" & $now.nanosecond & "-" & $runSequence
  var messages: seq[Message] = @[]
  messages.add(session.messages)
  if options.systemPrompt.len > 0:
    messages.insert(newMessage(ROLE_SYSTEM, options.systemPrompt), 0)
  messages.add(newMessage(ROLE_USER, prompt))
  try:
    emitEvent(options.events, "run.started", session.id, runId, newJNull())
    let maxSteps = if options.maxSteps > 0: options.maxSteps else: 8
    var total = newUsage()
    let limits = callLimit(options.modelCallLimit, options.toolCallLimit)
    for step in 1 .. maxSteps:
      var specs = toolSpecs(options.tools)
      if options.allowedTools.len > 0:
        var filtered: seq[ToolSpec] = @[]
        for spec in specs:
          if spec.name in options.allowedTools:
            filtered.add(spec)
        specs = filtered
      if options.toolSelection.isSome:
        specs = selectTools(options.toolSelection.get(), specs)
      var modelMessages = messages
      if options.pii:
        modelMessages = @[]
        for original in messages:
          var message = original
          message.content = piiRedact(message.content)
          message.contentBlocks = @[]
          for originalBlock in original.contentBlocks:
            var item = originalBlock
            item.text = piiRedact(item.text)
            message.contentBlocks.add(item)
          var toolCalls: seq[ToolCall] = @[]
          for originalCall in original.toolCalls:
            var call = originalCall
            call.arguments = redactValue(call.arguments)
            toolCalls.add(call)
          message.toolCalls = toolCalls
          modelMessages.add(message)
      limits.modelCall()
      authorize(options, newAction("model.generate", session.id))
      let response =
        if options.onDelta.isNil:
          options.model.generate(newRequest(modelMessages, specs))
        else:
          options.model.generateStream(newRequest(modelMessages, specs), options.onDelta)
      total = addUsage(total, response.usage)
      if options.maxTokens > 0 and total.inputTokens + total.outputTokens > options.maxTokens:
        raisePraxo("AGENT_MAX_TOKENS", "token budget exceeded")
      messages.add(response.message)
      if response.message.toolCalls.len == 0:
        var output = response.message.content
        if options.structuredOutput.isSome:
          let checked = options.structuredOutput.get().apply(output)
          if checked.code.len > 0:
            raisePraxo(checked.code, "structured output validation failed")
          output = checked.output
        emitEvent(options.events, "run.completed", session.id, runId, newJNull())
        return newRunResult(runId, output, step, total)
      for call in response.message.toolCalls:
        let originalName = call.name
        let originalArguments = copyJson(call.arguments)
        if not toolAllowed(options, originalName):
          raisePraxo("AGENT_TOOL_NOT_ALLOWED", "agent: tool " & originalName & " is not allowed")
        authorize(options, newAction("tool.invoke", session.id, originalName,
                                     copyJson(originalArguments)))
        var active = call
        for handler in options.middleware:
          handler(runId, session.id, active)
        if not toolAllowed(options, active.name):
          raisePraxo("AGENT_TOOL_NOT_ALLOWED", "agent: tool " & active.name & " is not allowed")
        let outcome = applyInterrupt(options, active, runId, session.id)
        if outcome.skip:
          messages.add(newMessageTool(encodeJson(%outcome.response), active.id))
          continue
        if not toolAllowed(options, active.name):
          raisePraxo("AGENT_TOOL_NOT_ALLOWED", "agent: tool " & active.name & " is not allowed")
        if active.name != originalName or not jsonEquals(active.arguments, originalArguments):
          authorize(options, newAction("tool.invoke", session.id, active.name,
                                       copyJson(active.arguments)))
        let index = findToolIndex(options.tools, active.name)
        if index < 0:
          raisePraxo("TOOL_NOT_FOUND", "tool not found: " & active.name)
        if options.toolSelection.isSome:
          checkToolSelected(options.toolSelection.get(), active.name)
        limits.toolCall()
        var data = newJObject()
        data["name"] = %active.name
        data["arguments"] = if active.arguments.isNil: newJObject() else: active.arguments
        emitEvent(options.events, "tool.call", session.id, runId, data)
        let value = options.tools[index].call(active.arguments)
        messages.add(newMessageTool(encodeJson(if options.pii: redactValue(value) else: value), active.id))
    raisePraxo("AGENT_MAX_STEPS", "maximum steps exceeded")
  except CatchableError as error:
    var data = newJObject()
    data["error"] = %error.msg
    try:
      emitEvent(options.events, "run.failed", session.id, runId, data)
    except CatchableError:
      discard
    raise
