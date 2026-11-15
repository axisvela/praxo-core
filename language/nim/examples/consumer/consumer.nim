import std/json
import praxo

type
  Recorder = ref object
    effects: int

let recorder = Recorder()

proc targetOf(arguments: JsonNode): string =
  if arguments.isNil or arguments.kind != JObject or not arguments.hasKey("target"):
    return ""
  return arguments["target"].getStr()

proc authorizeTarget(target: string) =
  if target != "public":
    raisePraxo("AGENT_POLICY_DENIED", "only the public target is permitted")

proc record(arguments: JsonNode): JsonNode =
  authorizeTarget(targetOf(arguments))
  inc recorder.effects
  return %"recorded"

proc fixtureModel(target: string): Model =
  return callbackModel(proc(request: Request): Response =
    if request.messages.len > 0 and request.messages[^1].role == ROLE_TOOL:
      return newResponse(newMessageAssistant("recorded"))
    return newResponse(newMessageAssistant("", @[
      newToolCall("record-1", "record", %*{"target": target})
    ]))
  )

proc runCase(target: string): tuple[result: RunResult, caught: ref CatchableError, effects: int] =
  recorder.effects = 0
  var options = newAgentOptions(fixtureModel(target))
  options.tools = @[newTool("record", "Record a target in an in-memory counter.", record)]
  options.allowedTools = @["record"]
  options.policy = proc(kind: string): bool =
    kind == "model.generate" or kind == "tool.invoke"
  options.maxSteps = 3
  options.requirePolicy = true
  options.requireToolScope = true
  try:
    let value = runAgent(options, newSession("consumer-" & target),
                         "Record the requested target.")
    return (result: value, caught: nil, effects: recorder.effects)
  except CatchableError as error:
    return (result: RunResult(), caught: error, effects: recorder.effects)

proc main() =
  let allowed = runCase("public")
  if allowed.caught != nil or allowed.result.output != "recorded" or allowed.effects != 1:
    stderr.writeLine("allow verification failed: output=" & allowed.result.output &
                     " effects=" & $allowed.effects)
    quit(1)
  echo "allow: recorded; effects=1"

  let denied = runCase("private")
  if denied.caught == nil or errorCode(denied.caught) != "AGENT_POLICY_DENIED" or
      denied.effects != 0:
    stderr.writeLine("deny verification failed: effects=" & $denied.effects &
                     " error=" & (if denied.caught == nil: "<none>" else: denied.caught.msg))
    quit(1)
  echo "deny: policy rejected; effects=0"

main()
