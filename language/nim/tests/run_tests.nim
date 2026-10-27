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
echo "nim tests passed"
