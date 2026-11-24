import std/json
import std/os
import praxo

const
  scopeField = "field-100"
  scopeAction = "request_irrigation"

type
  Counters = ref object
    reads: int
    drafts: int

  Outcome = object
    output: string
    reads: int
    drafts: int
    error: ref CatchableError

proc argStr(arguments: JsonNode, key: string): string =
  if arguments.isNil or arguments.kind != JObject or not arguments.hasKey(key):
    return ""
  return arguments[key].getStr()

proc buildModel(field: string): Model =
  return callbackModel(proc(request: Request): Response =
    var tools: seq[JsonNode] = @[]
    for message in request.messages:
      if message.role == ROLE_TOOL:
        tools.add(parseJson(message.content))
    if tools.len == 0:
      return newResponse(newMessageAssistant("", @[
        newToolCall("soil-1", "read_soil", %*{"field": field})
      ]))
    if tools.len == 1:
      return newResponse(newMessageAssistant("", @[
        newToolCall("draft-1", "draft_irrigation",
          %*{"field": field, "action": scopeAction})
      ]))
    let report = %*{
      "stage": "irrigation_request_drafted",
      "soil": tools[0],
      "request": tools[^1],
      "actuators": 0
    }
    return newResponse(newMessageAssistant($report))
  )

proc runCase(field: string, simulateFailure: bool): Outcome =
  let counters = Counters()
  let readTool = newTool(
    "read_soil",
    "Read fixed soil and weather observations for one field; no actuators.",
    proc(arguments: JsonNode): JsonNode =
      counters.reads.inc
      if simulateFailure:
        raisePraxo("SOIL_DATA_UNAVAILABLE", "synthetic soil observations unavailable")
      return %*{
        "field": field,
        "moisture_pct": 18,
        "threshold_pct": 25,
        "rain_forecast_mm": 2,
        "deficit": true,
        "source": "soil_fixture"
      }
  )
  let draftTool = newTool(
    "draft_irrigation",
    "Draft a bounded review-only irrigation request; never opens a valve.",
    proc(arguments: JsonNode): JsonNode =
      counters.drafts.inc
      return %*{
        "request_id": "irrigation-100",
        "field": field,
        "action": argStr(arguments, "action"),
        "gallons": 120,
        "status": "draft_only",
        "review_required": true,
        "actuators": 0
      }
  )

  var options = newAgentOptions(buildModel(field))
  options.tools = @[readTool, draftTool]
  options.allowedTools = @["read_soil", "draft_irrigation"]
  options.maxSteps = 4
  options.requirePolicy = true
  options.requireToolScope = true
  options.policy = proc(action: Action): Decision =
    if action.kind == "model.generate":
      return newDecision(true)
    if action.kind != "tool.invoke":
      return newDecision(false, "unsupported action")
    if argStr(action.arguments, "field") != scopeField:
      return newDecision(false, "only field-100 is in irrigation scope")
    if action.toolName == "read_soil":
      return newDecision(true)
    if action.toolName == "draft_irrigation":
      return newDecision(argStr(action.arguments, "action") == scopeAction,
                         "only a field-100 request_irrigation draft is allowed")
    return newDecision(false, "unsupported tool")

  try:
    let run = runAgent(options, newSession("irrigation-plan"),
                       "Evaluate fixed soil observations and draft a bounded irrigation request.")
    return Outcome(output: run.output, reads: counters.reads,
                   drafts: counters.drafts, error: nil)
  except CatchableError as error:
    return Outcome(output: "", reads: counters.reads,
                   drafts: counters.drafts, error: error)

proc runTests() =
  let success = runCase(scopeField, false)
  if success.error != nil or success.reads != 1 or success.drafts != 1:
    stderr.writeLine("success failed")
    quit(1)
  let report = parseJson(success.output)
  if report["stage"].getStr() != "irrigation_request_drafted" or
      report["soil"]["deficit"].getBool() != true or
      report["request"]["status"].getStr() != "draft_only" or
      report["actuators"].getInt() != 0:
    stderr.writeLine("unexpected report: " & success.output)
    quit(1)
  echo "success: field-100 moisture=18 status=draft_only actuators=0 reads=1"

  let denied = runCase("field-200", false)
  if denied.error == nil or errorCode(denied.error) != "AGENT_POLICY_DENIED" or
      denied.reads != 0 or denied.drafts != 0:
    stderr.writeLine("deny failed")
    quit(1)
  echo "deny: AGENT_POLICY_DENIED reads=0"

  let failed = runCase(scopeField, true)
  if failed.error == nil or errorCode(failed.error) != "SOIL_DATA_UNAVAILABLE" or
      failed.reads != 1 or failed.drafts != 0:
    stderr.writeLine("failure failed")
    quit(1)
  echo "failure: SOIL_DATA_UNAVAILABLE reads=1"

proc main() =
  let args = commandLineParams()
  if "--test" in args:
    runTests()
    return
  var field = scopeField
  let index = args.find("--field")
  if index >= 0 and index + 1 < args.len:
    field = args[index + 1]
  let outcome = runCase(field, "--simulate-failure" in args)
  if outcome.error != nil:
    stderr.writeLine("irrigation plan failed: " & outcome.error.msg)
    quit(1)
  echo outcome.output

main()
