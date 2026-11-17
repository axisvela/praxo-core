import std/[json, tables]
import praxo/agent
import praxo/delegation
import praxo/errors
import praxo/models

type
  DemoState = ref object
    effects: Table[string, int]
    childCalls: int

proc demoParentPolicy(action: Action): Decision =
  if action.kind == "model.generate":
    return newDecision(true)
  if action.kind == "tool.invoke" and action.toolName == "delegate":
    return newDecision(true)
  return newDecision(false, "parent may only delegate")

proc demoChildPolicy(action: Action): Decision =
  if action.kind == "model.generate":
    return newDecision(true)
  if action.kind == "tool.invoke" and action.toolName == "record":
    return newDecision(true)
  return newDecision(false, "child may only record")

proc recordCall(id: string, target: string): ToolCall =
  newToolCall(id, "record", %*{"target": target})

proc main() =
  let state = DemoState(effects: initTable[string, int]())
  let record = newTool("record", "Record a target in an in-memory counter",
    proc(arguments: JsonNode): JsonNode =
      let target = arguments["target"].getStr
      state.effects[target] = state.effects.getOrDefault(target) + 1
      return %("recorded:" & target))

  let childModel = callbackModel(proc(request: Request): Response =
    inc state.childCalls
    if state.childCalls == 1:
      return newResponse(newMessageAssistant("", @[recordCall("child-record", "child")]))
    return newResponse(newMessageAssistant("child done")))

  let delegate = newTool("delegate",
    "Run a child agent with a narrowed record scope",
    proc(arguments: JsonNode): JsonNode =
      var options = newAgentOptions(childModel)
      options.tools = @[record]
      options.maxSteps = 3
      options.allowedTools = @["record"]
      options.policy = demoChildPolicy
      options.requirePolicy = true
      options.requireToolScope = true
      let result = runAgent(options, newSession("demo-child"), "record child")
      return %result.output)

  let parentModel = scriptedModel(@[
    newResponse(newMessageAssistant("", @[
      newToolCall("parent-delegate", "delegate", %*{"task": "record child"})
    ])),
    newResponse(newMessageAssistant("parent done")),
  ])
  var options = newAgentOptions(parentModel)
  options.tools = @[record, delegate]
  options.allowedTools = @["delegate"]
  options.policy = demoParentPolicy
  options.requirePolicy = true
  options.requireToolScope = true
  let result = runAgent(options, newSession("demo-parent"), "delegate")
  echo "delegation: child recorded; parent scope enforced"
  doAssert result.output == "parent done"
  doAssert state.effects.getOrDefault("child") == 1

  let directModel = scriptedModel(@[
    newResponse(newMessageAssistant("", @[recordCall("direct-record", "child")])),
    newResponse(newMessageAssistant("parent done")),
  ])
  var directOptions = newAgentOptions(directModel)
  directOptions.tools = @[record, delegate]
  directOptions.allowedTools = @["delegate"]
  directOptions.policy = demoParentPolicy
  directOptions.requirePolicy = true
  directOptions.requireToolScope = true
  var denied = false
  try:
    discard runAgent(directOptions, newSession("demo-direct"), "record directly")
  except PraxoError:
    denied = true
  echo "deny: parent record blocked; child effect unchanged"
  doAssert denied
  doAssert state.effects.getOrDefault("child") == 1

when isMainModule:
  main()
