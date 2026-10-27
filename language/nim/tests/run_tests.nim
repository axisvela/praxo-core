import std/json
import std/options

import praxo

proc testJson() =
  let value = parseJsonText("""{"name":"echo","input":{"text":"hi"}}""")
  assert getString(value, "name") == "echo"
  let other = parseJsonText("""{"input":{"text":"hi"},"name":"echo"}""")
  assert jsonEquals(value, other)
  let roundtrip = parseJsonText(encodeJson(value))
  assert jsonEquals(value, roundtrip)

proc testToolcall() =
  let call = parseToolCall("""{"name":"echo","input":{"text":"hi"}}""")
  assert call.isSome
  assert call.get().name == "echo"
  assert parseToolCall("plain text").isNone
  let xml = parseToolCall("""<tool_call name="echo">{"text":"hi"}</tool_call>""")
  assert xml.isSome and xml.get().name == "echo"
  let tag = parseToolCall("""<echo.echo>{"text":"hi"}</echo.echo>""")
  assert tag.isSome and tag.get().name == "echo.echo"
  let plain = parseToolCall("""echo.run {"text":"hi"}""")
  assert plain.isSome and plain.get().name == "echo.run"
  assert stripToolCallMarkup("""hello<tool_call name="echo">{"text":"hi"}</tool_call>world""") == "helloworld"

proc testJsonschema() =
  let schema = parseJsonText("""{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}""")
  assert validateSchema(schema, parseJsonText("""{"name":"ok"}""")).len == 0
  let errors = validateSchema(schema, parseJsonText("{}"))
  assert errors.len == 1
  assert errors[0].path == "$.name"
  let pattern = parseJsonText("""{"type":"string","pattern":"^a+$"}""")
  assert validateSchema(pattern, %"aaa").len == 0
  assert validateSchema(pattern, %"b").len == 1

proc testPlugin() =
  let raw = """{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},"protocol":"jsonrpc-2","capabilities":["echo"],"permissions":{},"limits":{},"health":{},"isolation":"process"}"""
  let manifest = parseManifest(raw)
  assert manifest.id == "com.example.echo"
  var valid = true
  try:
    discard parseManifest(raw & "{}")
  except PraxoError:
    valid = false
  assert not valid

proc testMemory() =
  let store = newMemoryStore()
  discard store.memoryPut("s1", newMemoryRecord("m1", "event", "Alpha", "2026-01-01T00:00:00Z"))
  discard store.memoryPut("s1", newMemoryRecord("m2", "event", "beta", "2026-01-02T00:00:00Z"))
  discard store.memoryPut("s1", newMemoryRecord("m3", "decision", "ALPHABET", "2026-01-03T00:00:00Z"))
  let records = store.memorySearch("s1", "alpha", 10)
  assert records.len == 2
  assert records[0].id == "m3"
  assert records[1].id == "m1"
  assert store.memorySearch("s1", "alpha", 1)[0].id == "m3"
  assert store.memorySearch("s2", "alpha", 10).len == 0

proc testCheckpoint() =
  let allow = newCheckpointAllowlist()
  allow.register("spec.payload")
  let value = parseJsonText("""{"value":"x"}""")
  let data = allow.marshal("spec.payload", value)
  assert jsonEquals(allow.unmarshal(data), value)
  try:
    discard allow.marshal("spec.missing", newJNull())
    assert false
  except PraxoError as error:
    assert errorCode(error) == "CHECKPOINT_TYPE_NOT_ALLOWED"

proc testPaths() =
  assert normalizePath("../allowed/secret") == "../allowed/secret"
  assert normalizePath("../../allowed/secret") == "../../allowed/secret"
  assert normalizePath("a/../../../allowed") == "../../allowed"
  assert normalizePath("../a/../b") == "../b"
  assert normalizePath("/../../allowed") == "/allowed"
  let checker = newPathChecker(@[PathGrant(root: "allowed", access: "read")])
  assert checker.pathAllowed("allowed/secret", "read")
  assert checker.pathAllowed("a/../allowed/secret", "read")
  assert not checker.pathAllowed("../allowed/secret", "read")
  assert not checker.pathAllowed("../../allowed/secret", "read")
  assert not checker.pathAllowed("a/../../../allowed/secret", "read")

proc testContext() =
  let messages = @[
    newMessage(ROLE_SYSTEM, "sys"),
    newMessage(ROLE_USER, "message 0"),
    newMessage(ROLE_USER, "message 1"),
  ]
  assert estimateTokens(messages) == 16
  let (output, ok) = compactContext(newContextBudget(0, 0), messages)
  assert ok
  assert output.len == 3

proc testPii() =
  assert piiRedact("email a@b.com") == "email [REDACTED:email]"
  assert piiRedact("ssn 123-45-6789") == "ssn [REDACTED:ssn]"

proc testAgent() =
  let model = scriptedModel(@[
    newResponse(newMessageAssistant("hello")),
  ])
  let sink = newSink()
  var options = newAgentOptions(model)
  options.events = sink
  let result = runAgent(options, newSession("s1"), "hello")
  assert result.output == "hello"
  assert result.steps == 1
  assert sink.kinds == @["run.started", "run.completed"]

proc testAgentTool() =
  let model = scriptedModel(@[
    newResponse(newMessageAssistant("", @[
      newToolCall("c1", "echo", %*{"text": "hi"}),
    ])),
    newResponse(newMessageAssistant("done")),
  ])
  let tool = newTool("echo", "Echo")
  let sink = newSink()
  var options = newAgentOptions(model)
  options.tools = @[tool]
  options.events = sink
  let result = runAgent(options, newSession("s1"), "use")
  assert result.output == "done"
  assert tool.calls == 1
  assert sink.kinds == @["run.started", "tool.call", "run.completed"]

proc testCallbackModel() =
  var calls = 0
  let model = callbackModel(proc(request: Request): Response =
    inc calls
    assert request.tools.len == 1 and request.tools[0].name == "echo"
    assert request.messages[0].role == ROLE_SYSTEM
    assert request.messages[1].content == "previous"
    assert request.messages[2].content == "use"
    if calls == 1:
      assert request.messages.len == 3
      return newResponse(newMessageAssistant("", @[
        newToolCall("c1", "echo", %*{"text": "hi"})]), newUsage(2, 3))
    assert request.messages.len == 5
    assert request.messages[3].toolCalls[0].id == "c1"
    assert request.messages[4].role == ROLE_TOOL
    assert request.messages[4].toolId == "c1"
    assert parseJsonText(request.messages[4].content)["text"].getStr == "hi"
    return newResponse(newMessageAssistant("done"), newUsage(4, 5))
  )
  var options = newAgentOptions(model)
  options.systemPrompt = "system"
  options.tools = @[newTool("echo", "Echo")]
  let result = runAgent(options, newSession("s1", @[newMessage(ROLE_USER, "previous")]), "use")
  assert calls == 2 and result.steps == 2 and result.output == "done"
  assert result.usage.inputTokens == 6 and result.usage.outputTokens == 8

proc testCallbackErrors() =
  let failing = callbackModel(proc(request: Request): Response =
    raise newException(ValueError, "provider failed")
  )
  let sink = newSink()
  var options = newAgentOptions(failing)
  options.events = sink
  try:
    discard runAgent(options, newSession("s1"), "hello")
    assert false
  except ValueError as error:
    assert error.msg == "provider failed"
  assert sink.kinds == @["run.started", "run.failed"]
  options.model = fallbackModel(failing, staticModel("recovered"))
  assert runAgent(options, newSession("s1"), "hello").output == "recovered"
  options.model = callbackModel(nil)
  try:
    discard runAgent(options, newSession("s1"), "hello")
    assert false
  except PraxoError as error:
    assert errorCode(error) == "MODEL_ERROR"

proc testAgentToolSelection() =
  let allowed = newTool("allowed", "Allowed")
  var invoked = false
  let denied = newTool("denied", "Denied", proc(arguments: JsonNode): JsonNode =
    invoked = true
    return arguments
  )
  var calls = 0
  let model = callbackModel(proc(request: Request): Response =
    inc calls
    assert request.tools.len == 1
    assert request.tools[0].name == "allowed"
    assert request.tools[0].description == "Allowed"
    if calls == 1:
      return newResponse(newMessageAssistant("", @[
        newToolCall("c1", "allowed", newJObject())]))
    return newResponse(newMessageAssistant("", @[
      newToolCall("c2", "denied", newJObject())]))
  )
  let sink = newSink()
  var options = newAgentOptions(model)
  options.tools = @[allowed, denied]
  options.events = sink
  options.toolSelection = some(toolSelection(@["allowed"]))
  try:
    discard runAgent(options, newSession("s1"), "use")
    assert false
  except PraxoError as error:
    assert errorCode(error) == "AGENT_TOOL_NOT_SELECTED"
  assert calls == 2 and allowed.calls == 1
  assert denied.calls == 0 and not invoked
  assert sink.kinds == @["run.started", "tool.call", "run.failed"]

  options.toolSelection = some(toolSelection(@[]))
  options.model = callbackModel(proc(request: Request): Response =
    assert request.tools.len == 0
    return newResponse(newMessageAssistant("", @[
      newToolCall("c3", "allowed", newJObject())]))
  )
  try:
    discard runAgent(options, newSession("s1"), "use")
    assert false
  except PraxoError as error:
    assert errorCode(error) == "AGENT_TOOL_NOT_SELECTED"
  assert allowed.calls == 1

  options.toolSelection = none(ToolSelection)
  options.model = callbackModel(proc(request: Request): Response =
    assert request.tools.len == 2
    return newResponse(newMessageAssistant("done"))
  )
  assert runAgent(options, newSession("s1"), "use").output == "done"

testJson()
testToolcall()
testJsonschema()
testPlugin()
testMemory()
testCheckpoint()
testPaths()
testContext()
testPii()
testAgent()
testAgentTool()
testCallbackModel()
testCallbackErrors()
testAgentToolSelection()
echo "nim tests passed"
