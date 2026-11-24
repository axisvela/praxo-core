import std/json
import std/os
import praxo

const
  scopeZone = "zone-100"
  scopeAction = "draft_inspection"

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

proc buildModel(zone: string): Model =
  return callbackModel(proc(request: Request): Response =
    var tools: seq[JsonNode] = @[]
    for message in request.messages:
      if message.role == ROLE_TOOL:
        tools.add(parseJson(message.content))
    if tools.len == 0:
      return newResponse(newMessageAssistant("", @[
        newToolCall("pressure-1", "read_pressure", %*{"zone": zone})
      ]))
    if tools.len == 1:
      return newResponse(newMessageAssistant("", @[
        newToolCall("inspect-1", "draft_inspection",
          %*{"zone": zone, "action": scopeAction})
      ]))
    let report = %*{
      "stage": "inspection_drafted",
      "pressure": tools[0],
      "inspection": tools[^1],
      "isolations": 0
    }
    return newResponse(newMessageAssistant($report))
  )

proc runCase(zone: string, simulateFailure: bool): Outcome =
  let counters = Counters()
  let readTool = newTool(
    "read_pressure",
    "Rank fixed pressure anomalies for one zone; no valve operation.",
    proc(arguments: JsonNode): JsonNode =
      counters.reads.inc
      if simulateFailure:
        raisePraxo("PRESSURE_DATA_UNAVAILABLE", "synthetic pressure series unavailable")
      return %*{
        "zone": zone,
        "anomalies": 2,
        "max_drop_kpa": 35,
        "ranked_valves": @["valve-12", "valve-7"],
        "source": "pressure_fixture"
      }
  )
  let draftTool = newTool(
    "draft_inspection",
    "Draft a review-only inspection request; never isolates a valve or dispatches.",
    proc(arguments: JsonNode): JsonNode =
      counters.drafts.inc
      return %*{
        "inspection_id": "inspection-100",
        "zone": zone,
        "action": argStr(arguments, "action"),
        "status": "draft_only",
        "review_required": true,
        "isolations": 0
      }
  )

  var options = newAgentOptions(buildModel(zone))
  options.tools = @[readTool, draftTool]
  options.allowedTools = @["read_pressure", "draft_inspection"]
  options.maxSteps = 4
  options.requirePolicy = true
  options.requireToolScope = true
  options.policy = proc(action: Action): Decision =
    if action.kind == "model.generate":
      return newDecision(true)
    if action.kind != "tool.invoke":
      return newDecision(false, "unsupported action")
    if argStr(action.arguments, "zone") != scopeZone:
      return newDecision(false, "only zone-100 is in leak scope")
    if action.toolName == "read_pressure":
      return newDecision(true)
    if action.toolName == "draft_inspection":
      return newDecision(argStr(action.arguments, "action") == scopeAction,
                         "only a zone-100 draft_inspection is allowed")
    return newDecision(false, "unsupported tool")

  try:
    let run = runAgent(options, newSession("leak-localization"),
                       "Rank fixed pressure anomalies and draft a review-only inspection.")
    return Outcome(output: run.output, reads: counters.reads,
                   drafts: counters.drafts, error: nil)
  except CatchableError as error:
    return Outcome(output: "", reads: counters.reads,
                   drafts: counters.drafts, error: error)

proc runTests() =
  let success = runCase(scopeZone, false)
  if success.error != nil or success.reads != 1 or success.drafts != 1:
    stderr.writeLine("success failed")
    quit(1)
  let report = parseJson(success.output)
  if report["stage"].getStr() != "inspection_drafted" or
      report["pressure"]["anomalies"].getInt() != 2 or
      report["pressure"]["ranked_valves"][0].getStr() != "valve-12" or
      report["inspection"]["status"].getStr() != "draft_only" or
      report["isolations"].getInt() != 0:
    stderr.writeLine("unexpected report: " & success.output)
    quit(1)
  echo "success: zone-100 anomalies=2 top=valve-12 status=draft_only isolations=0 reads=1"

  let denied = runCase("zone-200", false)
  if denied.error == nil or errorCode(denied.error) != "AGENT_POLICY_DENIED" or
      denied.reads != 0 or denied.drafts != 0:
    stderr.writeLine("deny failed")
    quit(1)
  echo "deny: AGENT_POLICY_DENIED reads=0"

  let failed = runCase(scopeZone, true)
  if failed.error == nil or errorCode(failed.error) != "PRESSURE_DATA_UNAVAILABLE" or
      failed.reads != 1 or failed.drafts != 0:
    stderr.writeLine("failure failed")
    quit(1)
  echo "failure: PRESSURE_DATA_UNAVAILABLE reads=1"

proc main() =
  let args = commandLineParams()
  if "--test" in args:
    runTests()
    return
  var zone = scopeZone
  let index = args.find("--zone")
  if index >= 0 and index + 1 < args.len:
    zone = args[index + 1]
  let outcome = runCase(zone, "--simulate-failure" in args)
  if outcome.error != nil:
    stderr.writeLine("leak localization failed: " & outcome.error.msg)
    quit(1)
  echo outcome.output

main()
