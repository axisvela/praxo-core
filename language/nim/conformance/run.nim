import std/algorithm
import std/json
import std/options
import std/os
import std/strutils

import praxo

const groups = [
  "agent-loop",
  "checkpoint",
  "context",
  "event",
  "jsonschema",
  "memory",
  "middleware",
  "plugin",
  "policy",
  "stream",
  "toolcall",
]

proc check(condition: bool, message: string) =
  if not condition:
    raise newException(ValueError, message)

proc readText(path: string): string =
  return readFile(path)

proc inputOf(expect: JsonNode, key: string, fallback: JsonNode): JsonNode =
  let value = getNode(expect, key)
  if value.isNil:
    return fallback
  return value

proc runToolcall(input: JsonNode, expect: JsonNode) =
  let operation = getString(input, "operation")
  let content = getString(input, "content")
  if operation == "strip":
    check(stripToolCallMarkup(content) == getString(expect, "text"), "strip mismatch")
    return
  let call = parseToolCall(content)
  if getBool(expect, "nil"):
    check(call.isNone, "expected nil")
    return
  check(call.isSome, "expected a tool call")
  let value = call.get()
  check(value.name == getString(expect, "name"), "name mismatch")
  let expected = inputOf(expect, "input", newJObject())
  check(jsonEquals(value.arguments, expected), "input mismatch")

proc runJsonschema(input: JsonNode, expect: JsonNode) =
  let schema = inputOf(input, "schema", newJNull())
  let data = inputOf(input, "data", newJNull())
  let errors = validateSchema(schema, data)
  var paths: seq[string] = @[]
  for item in errors:
    paths.add(item.path)
  paths.sort()
  var expected: seq[string] = @[]
  for item in getArray(expect, "errorPaths"):
    if item.kind == JString:
      expected.add(item.getStr())
  expected.sort()
  check((errors.len == 0) == getBool(expect, "valid"), "valid mismatch")
  check(jsonEquals(fromStrings(paths), fromStrings(expected)), "errorPaths mismatch")

proc runPlugin(input: JsonNode, expect: JsonNode) =
  var raw = getString(input, "raw")
  if raw.len == 0:
    raw = encodeJson(inputOf(input, "manifest", newJNull()))
  var valid = true
  var manifest: Manifest
  try:
    manifest = parseManifest(raw)
  except PraxoError:
    valid = false
  check(valid == getBool(expect, "valid"), "valid mismatch")
  if not valid:
    return
  let expectedId = getString(expect, "id")
  if expectedId.len > 0:
    check(manifest.id == expectedId, "id mismatch")
  let expectedKind = getString(expect, "kind")
  if expectedKind.len > 0:
    check(manifest.kind == expectedKind, "kind mismatch")

proc runMemory(input: JsonNode, expect: JsonNode) =
  let store = newMemoryStore()
  for put in getArray(input, "puts"):
    let sessionId = getString(put, "session")
    let record = inputOf(put, "record", newJObject())
    discard store.memoryPut(sessionId, newMemoryRecord(
      getString(record, "id"),
      getString(record, "frame"),
      getString(record, "content"),
      getString(record, "createdAt")
    ))
  let records = store.memorySearch(
    getString(input, "session"),
    getString(input, "query"),
    getInt(input, "limit")
  )
  var ids: JsonNode = newJNull()
  var contents: JsonNode = newJNull()
  if records.len > 0:
    var idValues: seq[string] = @[]
    var contentValues: seq[string] = @[]
    for record in records:
      idValues.add(record.id)
      contentValues.add(record.content)
    ids = fromStrings(idValues)
    contents = fromStrings(contentValues)
  check(jsonEquals(ids, inputOf(expect, "ids", newJNull())), "ids mismatch")
  check(jsonEquals(contents, inputOf(expect, "contents", newJNull())), "contents mismatch")

proc runEvent(input: JsonNode, expect: JsonNode) =
  var events: seq[Event] = @[]
  for kind in getArray(input, "events"):
    if kind.kind == JString:
      events.add(newEvent(kind.getStr(), "s1"))
  if getString(input, "sink", "filter") == "multi":
    let count = max(1, getInt(input, "sinkCount", 1))
    var sinks: seq[Sink] = @[]
    for _ in 0 ..< count:
      sinks.add(newSink())
    let multi = multiSink(sinks)
    for event in events:
      multi.emit(event)
    var perSink = newJArray()
    for sink in sinks:
      perSink.add(fromStrings(sink.kinds))
    check(jsonEquals(perSink, inputOf(expect, "perSink", newJNull())), "perSink mismatch")
    return
  let base = newSink()
  var predicate: seq[string] = @[]
  for item in getArray(input, "predicateTypes"):
    if item.kind == JString:
      predicate.add(item.getStr())
  let filtered = filterSink(base, predicate)
  for event in events:
    filtered.emit(event)
  let delivered = if base.kinds.len > 0: fromStrings(base.kinds) else: newJNull()
  check(jsonEquals(delivered, inputOf(expect, "delivered", newJNull())), "delivered mismatch")

proc runStream(expect: JsonNode) =
  check(jsonEquals(fromStrings(streamKinds), inputOf(expect, "kinds", newJNull())),
    "kinds mismatch")

proc runCheckpoint(input: JsonNode, expect: JsonNode) =
  let allow = newCheckpointAllowlist()
  for kind in getArray(input, "registered"):
    if kind.kind == JString:
      allow.register(kind.getStr())
  let operation = getString(input, "operation", "roundtrip")
  let kind = getString(input, "type")
  let value = inputOf(input, "value", newJNull())
  if operation == "roundtrip":
    let data = allow.marshal(kind, value)
    check(jsonEquals(allow.unmarshal(data), inputOf(expect, "value", newJNull())),
      "value mismatch")
    return
  var code = ""
  try:
    if operation == "marshal":
      discard allow.marshal(kind, value)
    elif operation == "unmarshal":
      var envelope = newJObject()
      envelope["type"] = %kind
      envelope["data"] = value
      discard allow.unmarshal(encodeJson(envelope))
    else:
      code = "CHECKPOINT_ERROR"
  except PraxoError as error:
    code = errorCode(error)
  check(code == getString(expect, "errorCode"), "errorCode: got " & code)

proc runPolicy(input: JsonNode, expect: JsonNode) =
  var grants: seq[PathGrant] = @[]
  for item in getArray(input, "grants"):
    grants.add(newPathGrant(getString(item, "root"), getString(item, "access", "read")))
  let checker = newPathChecker(grants)
  let target = getString(input, "target")
  let need = getString(input, "need", "read")
  if getBool(expect, "error"):
    var failed = false
    try:
      discard checker.check(target, need)
    except PraxoError:
      failed = true
    check(failed, "expected a policy error")
    return
  let decision = checker.check(target, need)
  check(decision.allowed == getBool(expect, "allowed"), "allowed mismatch")

proc runContext(input: JsonNode, expect: JsonNode) =
  var messages: seq[Message] = @[]
  for item in getArray(input, "messages"):
    messages.add(newMessage(getString(item, "role"), getString(item, "content")))
  if getString(input, "operation") == "estimate":
    check(estimateTokens(messages) == getInt(expect, "tokens"), "tokens mismatch")
    return
  let budgetValue = inputOf(input, "budget", newJObject())
  let budget = newContextBudget(
    getInt(budgetValue, "maxTokens"),
    getInt(budgetValue, "keepRecent")
  )
  let (output, ok) = compactContext(budget, messages)
  check(ok == getBool(expect, "ok"), "ok mismatch")
  if not ok:
    return
  check(estimateTokens(output) == getInt(expect, "tokens"), "tokens mismatch")
  var wire = newJArray()
  for item in output:
    wire.add(messageWire(item))
  check(jsonEquals(wire, inputOf(expect, "messages", newJNull())), "messages mismatch")

proc runMiddleware(input: JsonNode, expect: JsonNode) =
  let operation = getString(input, "operation")
  if operation == "pii":
    check(piiRedact(getString(input, "text")) == getString(expect, "text"), "text mismatch")
  elif operation == "pii-value":
    check(jsonEquals(redactValue(inputOf(input, "value", newJNull())),
      inputOf(expect, "value", newJNull())), "value mismatch")
  elif operation == "structured":
    var config = structuredOutput(inputOf(input, "schema", newJNull()),
      getInt(input, "maxRepairs"))
    let repair = getString(input, "repairOutput")
    if repair.len > 0:
      config.repairer = proc(text: string): string = repair
    let (output, code) = config.apply(getString(input, "output"))
    if getBool(expect, "ok"):
      check(code.len == 0 and output == getString(expect, "output"), "output mismatch")
    else:
      check(code == getString(expect, "errorCode"), "errorCode mismatch")
  elif operation == "call-limit":
    let limit = callLimit(getInt(input, "modelLimit"), getInt(input, "toolLimit"))
    var outcomes: seq[string] = @[]
    for item in getArray(input, "calls"):
      let kind = if item.kind == JString: item.getStr() else: ""
      var code = "ok"
      try:
        if kind == "model":
          limit.modelCall()
        else:
          limit.toolCall()
      except PraxoError as error:
        code = errorCode(error)
      outcomes.add(code)
    check(jsonEquals(fromStrings(outcomes), inputOf(expect, "outcomes", newJNull())),
      "outcomes mismatch")
  elif operation == "tool-selection":
    var selected: seq[string] = @[]
    for item in getArray(input, "selected"):
      if item.kind == JString:
        selected.add(item.getStr())
    let selection = toolSelection(selected)
    var tools: seq[ToolSpec] = @[]
    for item in getArray(input, "tools"):
      if item.kind == JString:
        tools.add(newToolSpec(item.getStr(), ""))
    var names: seq[string] = @[]
    for item in selectTools(selection, tools):
      names.add(item.name)
    check(jsonEquals(fromStrings(names), inputOf(expect, "advertised", newJNull())),
      "advertised mismatch")
    var reject = "ok"
    try:
      checkToolSelected(selection, getString(input, "requested"))
    except PraxoError as error:
      reject = errorCode(error)
    check(reject == getString(expect, "reject"), "reject mismatch")
  elif operation == "fallback":
    let content = getString(input, "fallbackContent")
    let model = fallbackModel(failingModel(), staticModel(content))
    let result = model.generate(newRequest(@[]))
    check(result.message.content == content, "output mismatch")
  else:
    raise newException(ValueError, "unknown middleware operation " & operation)

proc runAgentLoop(input: JsonNode, expect: JsonNode) =
  var tools: seq[Tool] = @[]
  for item in getArray(input, "tools"):
    tools.add(newTool(getString(item, "name"), getString(item, "description")))
  var script: seq[Response] = @[]
  for item in getArray(input, "script"):
    var calls: seq[ToolCall] = @[]
    for call in getArray(item, "toolCalls"):
      let arguments = inputOf(call, "arguments", newJObject())
      calls.add(newToolCall(getString(call, "id"), getString(call, "name"), arguments))
    script.add(newResponse(
      newMessageAssistant(getString(item, "content"), calls),
      newUsage(getInt(item, "inputTokens"), getInt(item, "outputTokens"))
    ))
  let model = scriptedModel(script)
  var options = newAgentOptions(model)
  options.tools = tools
  options.maxSteps = getInt(input, "maxSteps")
  options.maxTokens = getInt(input, "maxTokens")
  let sink = newSink()
  options.events = sink
  let sessionValue = newSession("s1")
  var failure = ""
  var result: RunResult
  try:
    result = runAgent(options, sessionValue, getString(input, "prompt"))
  except PraxoError as error:
    failure = errorCode(error)
  if getBool(expect, "error"):
    check(failure.len > 0, "unexpected success")
    let expected = getString(expect, "errorCode")
    if expected.len > 0:
      check(failure == expected, "errorCode: got " & failure)
  else:
    check(failure.len == 0, "unexpected failure: " & failure)
    check(result.output == getString(expect, "output"), "output mismatch")
    check(result.steps == getInt(expect, "steps"), "steps mismatch")
  var invocations = 0
  for tool in tools:
    inc invocations, tool.calls
  check(invocations == getInt(expect, "toolInvocations"), "tool invocations mismatch")
  let events = if sink.kinds.len > 0: fromStrings(sink.kinds) else: newJNull()
  check(jsonEquals(events, inputOf(expect, "events", newJNull())), "events mismatch")

proc runVector(group: string, vector: JsonNode) =
  let input = inputOf(vector, "input", newJObject())
  let expect = inputOf(vector, "expect", newJObject())
  case group
  of "toolcall":
    runToolcall(input, expect)
  of "jsonschema":
    runJsonschema(input, expect)
  of "plugin":
    runPlugin(input, expect)
  of "memory":
    runMemory(input, expect)
  of "event":
    runEvent(input, expect)
  of "stream":
    runStream(expect)
  of "checkpoint":
    runCheckpoint(input, expect)
  of "policy":
    runPolicy(input, expect)
  of "context":
    runContext(input, expect)
  of "middleware":
    runMiddleware(input, expect)
  of "agent-loop":
    runAgentLoop(input, expect)
  else:
    raise newException(ValueError, "no runner for group " & group)

proc main() =
  let version = readText("spec/SPEC_VERSION").strip()
  var failures: seq[string] = @[]
  var seen: seq[string] = @[]
  for group in groups:
    let content = readText("spec/vectors/" & group & ".json")
    var file: JsonNode
    try:
      file = parseJson(content)
    except JsonParsingError:
      failures.add(group & ": invalid vector file")
      continue
    if getString(file, "group") != group:
      failures.add(group & ": group mismatch")
    if getString(file, "specVersion") != version:
      failures.add(group & ": specVersion mismatch")
    for vector in getArray(file, "vectors"):
      let id = getString(vector, "id")
      if id in seen:
        failures.add(group & "/" & id & ": duplicate id")
      seen.add(id)
      try:
        runVector(group, vector)
      except CatchableError as error:
        failures.add(group & "/" & id & ": " & error.msg)
  if failures.len == 0:
    echo "all spec vectors passed"
    return
  for failure in failures:
    stderr.writeLine(failure)
  quit(1)

main()
