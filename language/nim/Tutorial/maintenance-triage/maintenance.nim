import std/json
import std/os
import praxo

const
  scopeDevice = "device-100"
  scopeAction = "create_workorder"

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

proc buildModel(device: string): Model =
  return callbackModel(proc(request: Request): Response =
    var tools: seq[JsonNode] = @[]
    for message in request.messages:
      if message.role == ROLE_TOOL:
        tools.add(parseJson(message.content))
    if tools.len == 0:
      return newResponse(newMessageAssistant("", @[
        newToolCall("read-1", "read_telemetry", %*{"device": device})
      ]))
    if tools.len == 1:
      return newResponse(newMessageAssistant("", @[
        newToolCall("draft-1", "draft_workorder",
          %*{"device": device, "action": scopeAction})
      ]))
    let report = %*{
      "stage": "workorder_drafted",
      "telemetry": tools[0],
      "workorder": tools[^1],
      "writes": 0
    }
    return newResponse(newMessageAssistant($report))
  )

proc runCase(device: string, simulateFailure: bool): Outcome =
  let counters = Counters()
  let readTool = newTool(
    "read_telemetry",
    "Read synthetic sensor telemetry for one device; no device writes.",
    proc(arguments: JsonNode): JsonNode =
      counters.reads.inc
      if simulateFailure:
        raisePraxo("TELEMETRY_UNAVAILABLE", "synthetic sensor telemetry unavailable")
      return %*{
        "device": device,
        "vibration_mm_s": 4.2,
        "temperature_c": 71,
        "indicator": "elevated",
        "source": "sensor_fixture"
      }
  )
  let draftTool = newTool(
    "draft_workorder",
    "Draft a review-only maintenance work order; never dispatches a technician.",
    proc(arguments: JsonNode): JsonNode =
      counters.drafts.inc
      return %*{
        "workorder_id": "wo-100",
        "device": device,
        "action": argStr(arguments, "action"),
        "status": "draft_only",
        "review_required": true,
        "writes": 0
      }
  )

  var options = newAgentOptions(buildModel(device))
  options.tools = @[readTool, draftTool]
  options.allowedTools = @["read_telemetry", "draft_workorder"]
  options.maxSteps = 4
  options.requirePolicy = true
  options.requireToolScope = true
  options.policy = proc(action: Action): Decision =
    if action.kind == "model.generate":
      return newDecision(true)
    if action.kind != "tool.invoke":
      return newDecision(false, "unsupported action")
    let target = argStr(action.arguments, "device")
    if target != scopeDevice:
      return newDecision(false, "only device-100 is in maintenance scope")
    if action.toolName == "read_telemetry":
      return newDecision(true)
    if action.toolName == "draft_workorder":
      return newDecision(argStr(action.arguments, "action") == scopeAction,
                         "only a device-100 create_workorder draft is allowed")
    return newDecision(false, "unsupported tool")

  try:
    let run = runAgent(options, newSession("maintenance-triage"),
                       "Triage the fixed device telemetry and draft a review-only work order.")
    return Outcome(output: run.output, reads: counters.reads,
                   drafts: counters.drafts, error: nil)
  except CatchableError as error:
    return Outcome(output: "", reads: counters.reads,
                   drafts: counters.drafts, error: error)

proc runTests() =
  let success = runCase(scopeDevice, false)
  if success.error != nil or success.reads != 1 or success.drafts != 1:
    stderr.writeLine("success failed: reads=" & $success.reads &
                     " drafts=" & $success.drafts & " error=" &
                     (if success.error == nil: "<none>" else: success.error.msg))
    quit(1)
  let report = parseJson(success.output)
  if report["stage"].getStr() != "workorder_drafted" or
      report["telemetry"]["indicator"].getStr() != "elevated" or
      report["workorder"]["status"].getStr() != "draft_only" or
      report["writes"].getInt() != 0:
    stderr.writeLine("unexpected report: " & success.output)
    quit(1)
  echo "success: device-100 indicator=elevated status=draft_only writes=0 reads=1"

  let denied = runCase("device-200", false)
  if denied.error == nil or errorCode(denied.error) != "AGENT_POLICY_DENIED" or
      denied.reads != 0 or denied.drafts != 0:
    stderr.writeLine("deny failed: reads=" & $denied.reads &
                     " drafts=" & $denied.drafts &
                     " error=" & (if denied.error == nil: "<none>" else: errorCode(denied.error)))
    quit(1)
  echo "deny: AGENT_POLICY_DENIED reads=0"

  let failed = runCase(scopeDevice, true)
  if failed.error == nil or errorCode(failed.error) != "TELEMETRY_UNAVAILABLE" or
      failed.reads != 1 or failed.drafts != 0:
    stderr.writeLine("failure failed: reads=" & $failed.reads &
                     " drafts=" & $failed.drafts &
                     " error=" & (if failed.error == nil: "<none>" else: errorCode(failed.error)))
    quit(1)
  echo "failure: TELEMETRY_UNAVAILABLE reads=1"

proc main() =
  let args = commandLineParams()
  if "--test" in args:
    runTests()
    return
  var device = scopeDevice
  let index = args.find("--device")
  if index >= 0 and index + 1 < args.len:
    device = args[index + 1]
  let outcome = runCase(device, "--simulate-failure" in args)
  if outcome.error != nil:
    stderr.writeLine("maintenance triage failed: reads=" & $outcome.reads &
                     " drafts=" & $outcome.drafts & "; " & outcome.error.msg)
    quit(1)
  echo outcome.output

main()
