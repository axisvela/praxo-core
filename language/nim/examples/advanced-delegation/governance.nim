import std/[json, tables]
import praxo/agent
import praxo/delegation
import praxo/errors
import praxo/hitl
import praxo/models

type
  GovState = ref object
    effects: Table[string, int]
    budget: int
    children: int

  RunConfig = object
    allowed: seq[string]
    policy: Policy
    tools: seq[Tool]
    depth: int
    maxDepth: int
    maxChildren: int
    useBudget: bool
    useChildren: bool
    cancelled: bool
    editToBlocked: bool

proc allow(): Decision =
  newDecision(true)

proc deny(reason: string): Decision =
  newDecision(false, reason)

proc targetOf(action: Action): string =
  if action.arguments.kind == JObject and action.arguments.hasKey("target"):
    return action.arguments["target"].getStr
  return ""

proc permissiveRecord(action: Action): Decision =
  if action.kind == "model.generate":
    return allow()
  if action.kind == "tool.invoke" and action.toolName == "record":
    return allow()
  return deny("child may only record")

proc parentDenyBlocked(action: Action): Decision =
  if action.kind == "model.generate":
    return allow()
  if action.kind != "tool.invoke" or action.toolName != "record":
    return deny("parent tool is not allowed")
  if targetOf(action) == "blocked":
    return deny("blocked target")
  return allow()

proc composedPolicy(action: Action): Decision =
  let parent = parentDenyBlocked(action)
  if not parent.allowed:
    return parent
  return permissiveRecord(action)

proc deniedTask(status: string, code: string): SubagentTask =
  SubagentTask(status: status, error: code)

proc makeTools(state: GovState): seq[Tool] =
  result = @[]
  result.add(newTool("record", "record",
    proc(arguments: JsonNode): JsonNode =
      let target = arguments["target"].getStr
      state.effects[target] = state.effects.getOrDefault(target) + 1
      return %"ok"))
  result.add(newTool("write", "write",
    proc(arguments: JsonNode): JsonNode =
      let target = arguments["target"].getStr
      state.effects[target] = state.effects.getOrDefault(target) + 1
      return %"ok"))

proc modelFor(tool: string, target: string): Model =
  scriptedModel(@[
    newResponse(newMessageAssistant("", @[
      newToolCall("call-1", tool, %*{"target": target})
    ])),
    newResponse(newMessageAssistant("done")),
  ])

proc runChild(state: GovState, model: Model, config: RunConfig): SubagentTask =
  if config.cancelled:
    return deniedTask("cancelled", "CANCELLED")
  if config.maxDepth >= 0 and config.depth > config.maxDepth:
    return deniedTask("denied", "DEPTH_LIMIT")
  if config.maxChildren >= 0 and state.children >= config.maxChildren:
    return deniedTask("denied", "CHILD_LIMIT")
  if config.useBudget and state.budget <= 0:
    return deniedTask("denied", "BUDGET_EXHAUSTED")
  if config.useChildren:
    inc state.children
  var options = newAgentOptions(model)
  options.tools = config.tools
  options.maxSteps = 3
  options.allowedTools = config.allowed
  options.policy = config.policy
  options.requirePolicy = true
  options.requireToolScope = true
  if config.editToBlocked:
    options.interruptOn = @["record"]
    options.onInterruptDecision = proc(interrupt: Interrupt): InterruptDecision =
      newInterruptDecision(INTERRUPT_EDIT, %*{"target": "blocked"})
  let task = subagentRun(
    proc(request: SubagentRequest): SubagentResult =
      let result = runAgent(options, newSession("governance-child"), "run child")
      return newSubagentResult("child", "child", result.output),
    newSubagentRequest("governance-parent", "governance-child", "run child"))
  if config.useBudget and task.status == "completed":
    dec state.budget
  return task

proc main() =
  # 1. Child scope narrowing.
  let scopeState = GovState(effects: initTable[string, int]())
  let scope = runChild(scopeState, modelFor("write", "escape"), RunConfig(
    allowed: @["record"],
    policy: permissiveRecord,
    tools: makeTools(scopeState),
    maxDepth: -1,
    maxChildren: -1))
  doAssert scope.status == "failed"
  doAssert scopeState.effects.getOrDefault("escape") == 0

  # 2. Parent policy composition.
  let policyState = GovState(effects: initTable[string, int]())
  let composed = runChild(policyState, modelFor("record", "blocked"), RunConfig(
    allowed: @["record"],
    policy: composedPolicy,
    tools: makeTools(policyState),
    maxDepth: -1,
    maxChildren: -1))
  doAssert composed.status == "failed"
  doAssert policyState.effects.getOrDefault("blocked") == 0

  # 3. Shared sibling budget.
  let budgetState = GovState(effects: initTable[string, int](), budget: 1)
  let first = runChild(budgetState, modelFor("record", "sibling"), RunConfig(
    allowed: @["record"],
    policy: permissiveRecord,
    tools: makeTools(budgetState),
    maxDepth: -1,
    maxChildren: -1,
    useBudget: true))
  let second = runChild(budgetState, modelFor("record", "sibling"), RunConfig(
    allowed: @["record"],
    policy: permissiveRecord,
    tools: makeTools(budgetState),
    maxDepth: -1,
    maxChildren: -1,
    useBudget: true))
  doAssert first.status == "completed"
  doAssert second.status == "denied"
  doAssert second.error == "BUDGET_EXHAUSTED"
  doAssert budgetState.effects.getOrDefault("sibling") == 1

  # 4. Child-count and depth limits.
  let limitState = GovState(effects: initTable[string, int]())
  let firstLimit = runChild(limitState, modelFor("record", "limit"), RunConfig(
    allowed: @["record"],
    policy: permissiveRecord,
    tools: makeTools(limitState),
    maxDepth: -1,
    maxChildren: 1,
    useChildren: true))
  let secondLimit = runChild(limitState, modelFor("record", "limit"), RunConfig(
    allowed: @["record"],
    policy: permissiveRecord,
    tools: makeTools(limitState),
    maxDepth: -1,
    maxChildren: 1,
    useChildren: true))
  let deep = runChild(limitState, modelFor("record", "limit"), RunConfig(
    allowed: @["record"],
    policy: permissiveRecord,
    tools: makeTools(limitState),
    depth: 2,
    maxDepth: 1,
    maxChildren: -1))
  doAssert firstLimit.status == "completed"
  doAssert secondLimit.error == "CHILD_LIMIT"
  doAssert deep.error == "DEPTH_LIMIT"
  doAssert limitState.effects.getOrDefault("limit") == 1

  # 5. Cancellation before effects.
  let cancelState = GovState(effects: initTable[string, int]())
  let cancelled = runChild(cancelState, modelFor("record", "cancel"), RunConfig(
    allowed: @["record"],
    policy: permissiveRecord,
    tools: makeTools(cancelState),
    maxDepth: -1,
    maxChildren: -1,
    cancelled: true))
  doAssert cancelled.status == "cancelled"
  doAssert cancelState.effects.getOrDefault("cancel") == 0

  # 6. Final-argument reauthorization.
  let editState = GovState(effects: initTable[string, int]())
  let edited = runChild(editState, modelFor("record", "edit-me"), RunConfig(
    allowed: @["record"],
    policy: parentDenyBlocked,
    tools: makeTools(editState),
    maxDepth: -1,
    maxChildren: -1,
    editToBlocked: true))
  doAssert edited.status == "failed"
  doAssert editState.effects.getOrDefault("edit-me") == 0
  doAssert editState.effects.getOrDefault("blocked") == 0

  echo "Nim advanced delegation governance: 6/6 passed"

when isMainModule:
  main()
