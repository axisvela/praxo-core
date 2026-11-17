import std/[json, tables]
import praxo/agent
import praxo/errors
import praxo/hitl
import praxo/jsonutil
import praxo/models
import praxo/runtime
import praxo/adapters/harmovela_sink
import praxo/adapters/mcp
import praxo/adapters/otel_sink

type
  ChainState = ref object
    effects: Table[string, int]
    otel: seq[string]
    harmovela: seq[string]
    childCalls: int

proc targetOf(action: Action): string =
  if action.arguments.kind == JObject and action.arguments.hasKey("target"):
    return action.arguments["target"].getStr
  return ""

proc parentPolicy(action: Action): Decision =
  if action.kind == "model.generate":
    return newDecision(true)
  if action.kind != "tool.invoke":
    return newDecision(false, "unsupported action")
  if action.toolName == "record":
    if targetOf(action) == "blocked":
      return newDecision(false, "blocked target")
    return newDecision(true)
  if action.toolName == "delegate":
    return newDecision(true)
  return newDecision(false, "parent tool is not allowed")

proc childPolicy(action: Action): Decision =
  if action.kind == "model.generate":
    return newDecision(true)
  if action.kind == "tool.invoke" and action.toolName == "record":
    return newDecision(true)
  return newDecision(false, "child may only record")

proc composedPolicy(action: Action): Decision =
  let parent = parentPolicy(action)
  if not parent.allowed:
    return parent
  return childPolicy(action)

proc recordCall(id: string, target: string): ToolCall =
  newToolCall(id, "record", %*{"target": target})

proc delegateCall(id: string): ToolCall =
  newToolCall(id, "delegate", %*{"task": "record child"})

proc responseWith(call: ToolCall): Response =
  newResponse(newMessageAssistant("", @[call]))

proc finalResponse(text: string): Response =
  newResponse(newMessageAssistant(text))

proc main() =
  let state = ChainState(effects: initTable[string, int]())

  let transport = proc(methodName: string, params: JsonNode): JsonNode =
    if methodName == "initialize":
      return %*{"result": {
        "protocolVersion": "2024-11-05",
        "serverInfo": {"name": "fake-mcp"}
      }}
    if methodName == "tools/list":
      return %*{"result": {"tools": [{
        "name": "record",
        "description": "Record a target",
        "inputSchema": {
          "type": "object",
          "properties": {"target": {"type": "string"}},
          "required": ["target"]
        }
      }]}}
    if methodName == "tools/call":
      let target = params["arguments"]["target"].getStr
      state.effects[target] = state.effects.getOrDefault(target) + 1
      return %*{"result": {"content": [{
        "type": "text",
        "text": "recorded:" & target
      }]}}
    return newJObject()

  var client = mcpClient(transport)
  let tools = client.listTools()
  doAssert tools.len == 1

  let record = newTool("record", "Record a target through the MCP client",
    proc(arguments: JsonNode): JsonNode =
      let target = arguments["target"].getStr
      return client.callTool("record", %*{"target": target}))

  let otel = newOtelSink("http://otel.local/v1/traces",
    transport = proc(endpoint: string, body: string,
                     headers: seq[(string, string)]): OtelResponse =
      let payload = parseJsonText(body)
      for resource in payload["resourceSpans"]:
        for scope in resource["scopeSpans"]:
          for span in scope["spans"]:
            state.otel.add(span["name"].getStr)
      return OtelResponse(status: 200, body: ""))

  let harmovela = newHarmovelaSink("http://harmovela.local",
    transport = proc(path: string, body: string,
                     headers: seq[(string, string)]): HarmovelaResponse =
      let payload = parseJsonText(body)
      state.harmovela.add(payload["type"].getStr)
      return HarmovelaResponse(status: 202, body: ""))

  let events = multiSink(@[otel, harmovela])

  let delegate = newTool("delegate",
    "Run a governed child agent with the narrowed record scope",
    proc(arguments: JsonNode): JsonNode =
      let childModel = callbackModel(proc(request: Request): Response =
        inc state.childCalls
        if state.childCalls == 1:
          return responseWith(recordCall("child-record", "child"))
        return finalResponse("DONE"))
      var options = newAgentOptions(childModel)
      options.tools = @[record]
      options.maxSteps = 3
      options.allowedTools = @["record"]
      options.policy = composedPolicy
      options.requirePolicy = true
      options.requireToolScope = true
      options.events = events
      let result = runAgent(options, newSession("chain-child"), "record child")
      return %*{"output": result.output, "effects": state.effects.getOrDefault("child")})

  let parentModel = scriptedModel(@[
    responseWith(recordCall("parent-record", "parent")),
    responseWith(delegateCall("parent-delegate")),
    finalResponse("DONE"),
  ])
  var options = newAgentOptions(parentModel)
  options.tools = @[record, delegate]
  options.maxSteps = 4
  options.allowedTools = @["record", "delegate"]
  options.policy = parentPolicy
  options.requirePolicy = true
  options.requireToolScope = true
  options.events = events
  let parent = runAgent(options, newSession("chain-parent"),
    "record parent, then delegate")

  let deniedModel = scriptedModel(@[
    responseWith(recordCall("denied-record", "edit-me")),
    finalResponse("DONE"),
  ])
  var deniedOptions = newAgentOptions(deniedModel)
  deniedOptions.tools = @[record]
  deniedOptions.maxSteps = 2
  deniedOptions.allowedTools = @["record"]
  deniedOptions.policy = parentPolicy
  deniedOptions.requirePolicy = true
  deniedOptions.requireToolScope = true
  deniedOptions.events = events
  deniedOptions.interruptOn = @["record"]
  deniedOptions.onInterruptDecision = proc(interrupt: Interrupt): InterruptDecision =
    newInterruptDecision(INTERRUPT_EDIT, %*{"target": "blocked"})
  var deniedError = ""
  try:
    discard runAgent(deniedOptions, newSession("chain-denied"),
      "attempt a denied edit")
  except PraxoError as error:
    deniedError = error.msg

  client.close()
  echo "output: ", parent.output
  echo "effects: parent=", state.effects.getOrDefault("parent"),
    " child=", state.effects.getOrDefault("child")
  echo "child calls: ", state.childCalls
  echo "otel spans: ", state.otel.len
  echo "harmovela events: ", state.harmovela.len
  echo "denied effects: ", state.effects.getOrDefault("blocked")
  doAssert parent.output == "DONE"
  doAssert state.effects.getOrDefault("parent") == 1
  doAssert state.effects.getOrDefault("child") == 1
  doAssert state.childCalls == 2
  doAssert state.otel.len >= 3
  doAssert state.harmovela.len >= 3
  doAssert state.effects.getOrDefault("blocked") == 0
  doAssert deniedError.len > 0

when isMainModule:
  main()
