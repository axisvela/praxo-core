import std/json
import std/os
import praxo

const
  scopeShipment = "shipment-100"
  scopeAction = "review_transfer"

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

proc buildModel(shipment: string): Model =
  return callbackModel(proc(request: Request): Response =
    var tools: seq[JsonNode] = @[]
    for message in request.messages:
      if message.role == ROLE_TOOL:
        tools.add(parseJson(message.content))
    if tools.len == 0:
      return newResponse(newMessageAssistant("", @[
        newToolCall("temp-1", "read_temperature", %*{"shipment": shipment})
      ]))
    if tools.len == 1:
      return newResponse(newMessageAssistant("", @[
        newToolCall("transfer-1", "draft_transfer",
          %*{"shipment": shipment, "action": scopeAction})
      ]))
    let report = %*{
      "stage": "transfer_review_drafted",
      "temperature": tools[0],
      "transfer": tools[^1],
      "refrigeration_changes": 0
    }
    return newResponse(newMessageAssistant($report))
  )

proc runCase(shipment: string, simulateFailure: bool): Outcome =
  let counters = Counters()
  let readTool = newTool(
    "read_temperature",
    "Read fixed temperature excursions for one shipment; no refrigeration control.",
    proc(arguments: JsonNode): JsonNode =
      counters.reads.inc
      if simulateFailure:
        raisePraxo("TEMPERATURE_DATA_UNAVAILABLE", "synthetic temperature series unavailable")
      return %*{
        "shipment": shipment,
        "excursions": 2,
        "max_c": 12,
        "min_c": 2,
        "product": "vaccine",
        "source": "temperature_fixture"
      }
  )
  let draftTool = newTool(
    "draft_transfer",
    "Draft a review-only cargo transfer; never changes refrigeration.",
    proc(arguments: JsonNode): JsonNode =
      counters.drafts.inc
      return %*{
        "transfer_id": "transfer-100",
        "shipment": shipment,
        "action": argStr(arguments, "action"),
        "status": "draft_only",
        "review_required": true,
        "refrigeration_changes": 0
      }
  )

  var options = newAgentOptions(buildModel(shipment))
  options.tools = @[readTool, draftTool]
  options.allowedTools = @["read_temperature", "draft_transfer"]
  options.maxSteps = 4
  options.requirePolicy = true
  options.requireToolScope = true
  options.policy = proc(action: Action): Decision =
    if action.kind == "model.generate":
      return newDecision(true)
    if action.kind != "tool.invoke":
      return newDecision(false, "unsupported action")
    if argStr(action.arguments, "shipment") != scopeShipment:
      return newDecision(false, "only shipment-100 is in cold-chain scope")
    if action.toolName == "read_temperature":
      return newDecision(true)
    if action.toolName == "draft_transfer":
      return newDecision(argStr(action.arguments, "action") == scopeAction,
                         "only a shipment-100 review_transfer draft is allowed")
    return newDecision(false, "unsupported tool")

  try:
    let run = runAgent(options, newSession("cold-chain"),
                       "Evaluate fixed temperature excursions and draft a review-only transfer.")
    return Outcome(output: run.output, reads: counters.reads,
                   drafts: counters.drafts, error: nil)
  except CatchableError as error:
    return Outcome(output: "", reads: counters.reads,
                   drafts: counters.drafts, error: error)

proc runTests() =
  let success = runCase(scopeShipment, false)
  if success.error != nil or success.reads != 1 or success.drafts != 1:
    stderr.writeLine("success failed")
    quit(1)
  let report = parseJson(success.output)
  if report["stage"].getStr() != "transfer_review_drafted" or
      report["temperature"]["excursions"].getInt() != 2 or
      report["temperature"]["max_c"].getInt() != 12 or
      report["transfer"]["status"].getStr() != "draft_only" or
      report["refrigeration_changes"].getInt() != 0:
    stderr.writeLine("unexpected report: " & success.output)
    quit(1)
  echo "success: shipment-100 excursions=2 max_c=12 status=draft_only changes=0 reads=1"

  let denied = runCase("shipment-200", false)
  if denied.error == nil or errorCode(denied.error) != "AGENT_POLICY_DENIED" or
      denied.reads != 0 or denied.drafts != 0:
    stderr.writeLine("deny failed")
    quit(1)
  echo "deny: AGENT_POLICY_DENIED reads=0"

  let failed = runCase(scopeShipment, true)
  if failed.error == nil or errorCode(failed.error) != "TEMPERATURE_DATA_UNAVAILABLE" or
      failed.reads != 1 or failed.drafts != 0:
    stderr.writeLine("failure failed")
    quit(1)
  echo "failure: TEMPERATURE_DATA_UNAVAILABLE reads=1"

proc main() =
  let args = commandLineParams()
  if "--test" in args:
    runTests()
    return
  var shipment = scopeShipment
  let index = args.find("--shipment")
  if index >= 0 and index + 1 < args.len:
    shipment = args[index + 1]
  let outcome = runCase(shipment, "--simulate-failure" in args)
  if outcome.error != nil:
    stderr.writeLine("cold chain failed: " & outcome.error.msg)
    quit(1)
  echo outcome.output

main()
