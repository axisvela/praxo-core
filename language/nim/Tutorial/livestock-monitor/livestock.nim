import std/json
import std/os
import praxo

const
  scopeHerd = "herd-100"
  scopeAction = "request_review"

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

proc buildModel(herd: string): Model =
  return callbackModel(proc(request: Request): Response =
    var tools: seq[JsonNode] = @[]
    for message in request.messages:
      if message.role == ROLE_TOOL:
        tools.add(parseJson(message.content))
    if tools.len == 0:
      return newResponse(newMessageAssistant("", @[
        newToolCall("observe-1", "read_observations", %*{"herd": herd})
      ]))
    if tools.len == 1:
      return newResponse(newMessageAssistant("", @[
        newToolCall("review-1", "draft_review",
          %*{"herd": herd, "action": scopeAction})
      ]))
    let report = %*{
      "stage": "review_request_drafted",
      "observations": tools[0],
      "request": tools[^1],
      "treatments": 0
    }
    return newResponse(newMessageAssistant($report))
  )

proc runCase(herd: string, simulateFailure: bool): Outcome =
  let counters = Counters()
  let readTool = newTool(
    "read_observations",
    "Summarize fixed animal observations; no diagnosis or feeding control.",
    proc(arguments: JsonNode): JsonNode =
      counters.reads.inc
      if simulateFailure:
        raisePraxo("OBSERVATION_DATA_UNAVAILABLE", "synthetic herd observations unavailable")
      return %*{
        "herd": herd,
        "animals": 3,
        "flagged": 1,
        "max_temp_c": 39.8,
        "feed_intake_pct": 62,
        "source": "herd_fixture"
      }
  )
  let draftTool = newTool(
    "draft_review",
    "Draft a review-only livestock request; never isolates or feeds animals.",
    proc(arguments: JsonNode): JsonNode =
      counters.drafts.inc
      return %*{
        "request_id": "livestock-100",
        "herd": herd,
        "action": argStr(arguments, "action"),
        "status": "draft_only",
        "review_required": true,
        "treatments": 0
      }
  )

  var options = newAgentOptions(buildModel(herd))
  options.tools = @[readTool, draftTool]
  options.allowedTools = @["read_observations", "draft_review"]
  options.maxSteps = 4
  options.requirePolicy = true
  options.requireToolScope = true
  options.policy = proc(action: Action): Decision =
    if action.kind == "model.generate":
      return newDecision(true)
    if action.kind != "tool.invoke":
      return newDecision(false, "unsupported action")
    if argStr(action.arguments, "herd") != scopeHerd:
      return newDecision(false, "only herd-100 is in livestock scope")
    if action.toolName == "read_observations":
      return newDecision(true)
    if action.toolName == "draft_review":
      return newDecision(argStr(action.arguments, "action") == scopeAction,
                         "only a herd-100 request_review draft is allowed")
    return newDecision(false, "unsupported tool")

  try:
    let run = runAgent(options, newSession("livestock-monitor"),
                       "Summarize fixed observations and draft a review-only request.")
    return Outcome(output: run.output, reads: counters.reads,
                   drafts: counters.drafts, error: nil)
  except CatchableError as error:
    return Outcome(output: "", reads: counters.reads,
                   drafts: counters.drafts, error: error)

proc runTests() =
  let success = runCase(scopeHerd, false)
  if success.error != nil or success.reads != 1 or success.drafts != 1:
    stderr.writeLine("success failed")
    quit(1)
  let report = parseJson(success.output)
  if report["stage"].getStr() != "review_request_drafted" or
      report["observations"]["flagged"].getInt() != 1 or
      report["observations"]["max_temp_c"].getFloat() != 39.8 or
      report["request"]["status"].getStr() != "draft_only" or
      report["treatments"].getInt() != 0:
    stderr.writeLine("unexpected report: " & success.output)
    quit(1)
  echo "success: herd-100 flagged=1 status=draft_only treatments=0 reads=1"

  let denied = runCase("herd-200", false)
  if denied.error == nil or errorCode(denied.error) != "AGENT_POLICY_DENIED" or
      denied.reads != 0 or denied.drafts != 0:
    stderr.writeLine("deny failed")
    quit(1)
  echo "deny: AGENT_POLICY_DENIED reads=0"

  let failed = runCase(scopeHerd, true)
  if failed.error == nil or errorCode(failed.error) != "OBSERVATION_DATA_UNAVAILABLE" or
      failed.reads != 1 or failed.drafts != 0:
    stderr.writeLine("failure failed")
    quit(1)
  echo "failure: OBSERVATION_DATA_UNAVAILABLE reads=1"

proc main() =
  let args = commandLineParams()
  if "--test" in args:
    runTests()
    return
  var herd = scopeHerd
  let index = args.find("--herd")
  if index >= 0 and index + 1 < args.len:
    herd = args[index + 1]
  let outcome = runCase(herd, "--simulate-failure" in args)
  if outcome.error != nil:
    stderr.writeLine("livestock monitor failed: " & outcome.error.msg)
    quit(1)
  echo outcome.output

main()
