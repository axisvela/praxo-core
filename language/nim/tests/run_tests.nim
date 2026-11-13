import std/json
import std/options
import std/strutils
import std/times

import praxo
import praxo/adapters/anthropic
import praxo/adapters/gemini
import praxo/adapters/otel_sink
import praxo/retriever
import praxo/delegation

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
  assert piiRedact("Contact a@b.com. Next c@d.com...") ==
    "Contact [REDACTED:email]. Next [REDACTED:email]..."
  assert piiRedact("a@b.c. a@b. a@b.com, a@b.com!") ==
    "a@b.c. a@b. [REDACTED:email], [REDACTED:email]!"
  assert piiRedact("ssn 123-45-6789") == "ssn [REDACTED:ssn]"
  assert piiRedact("call 415-555-2671") == "call [REDACTED:phone]"
  assert piiRedact("call +1 (415) 555-2671.") == "call [REDACTED:phone]."
  assert piiRedact("version 1.2.3") == "version 1.2.3"

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

proc testRunIds() =
  let model = staticModel("ok")
  let first = runAgent(newAgentOptions(model), newSession("s1"), "hi")
  let second = runAgent(newAgentOptions(model), newSession("s1"), "hi")
  assert first.runId != second.runId

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

proc testAgentPii() =
  var history = newMessage(ROLE_USER, "a@b.com")
  history.contentBlocks = @[ContentBlock(kind: "text", text: "123-45-6789")]
  let session = newSession("s1", @[history])
  var calls = 0
  let tool = newTool("echo", "Echo", proc(arguments: JsonNode): JsonNode =
    assert arguments["email"].getStr == "a@b.com"
    return %*{"nested": ["a@b.com", {"ssn": "123-45-6789", "text": "Email a@b.com."}]}
  )
  let model = callbackModel(proc(request: Request): Response =
    inc calls
    assert request.messages[0].content == "[REDACTED:email]"
    assert request.messages[1].contentBlocks[0].text == "[REDACTED:ssn]"
    assert request.messages[1].content == "[REDACTED:email]"
    assert request.messages[2].content == "[REDACTED:email]"
    if calls == 1:
      return newResponse(newMessageAssistant("a@b.com", @[
        newToolCall("c1", "echo", %*{"email": "a@b.com"})]))
    assert request.messages[3].content == "[REDACTED:email]"
    assert request.messages[3].toolCalls[0].arguments["email"].getStr == "[REDACTED:email]"
    let value = parseJsonText(request.messages[4].content)
    assert value["nested"][0].getStr == "[REDACTED:email]"
    assert value["nested"][1]["ssn"].getStr == "[REDACTED:ssn]"
    assert value["nested"][1]["text"].getStr == "Email [REDACTED:email]."
    return newResponse(newMessageAssistant("a@b.com"))
  )
  var options = newAgentOptions(model)
  options.pii = true
  options.systemPrompt = "a@b.com"
  options.tools = @[tool]
  assert runAgent(options, session, "a@b.com").output == "a@b.com"
  assert session.messages[0].content == "a@b.com"
  assert session.messages[0].contentBlocks[0].text == "123-45-6789"
  options.pii = false
  options.model = callbackModel(proc(request: Request): Response =
    assert request.messages[0].content == "a@b.com"
    assert request.messages[1].content == "a@b.com"
    assert request.messages[2].content == "a@b.com"
    return newResponse(newMessageAssistant("ok"))
  )
  assert runAgent(options, session, "a@b.com").output == "ok"

proc testAgentStructuredOutput() =
  let schema = parseJsonText("""{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}""")
  let sink = newSink()
  var options = newAgentOptions(staticModel("invalid"))
  options.events = sink
  assert runAgent(options, newSession("s1"), "x").output == "invalid"
  options.structuredOutput = some(structuredOutput(schema, 1, proc(text: string): string =
    assert text == "invalid"
    return """{"name":"fixed"}"""
  ))
  assert runAgent(options, newSession("s1"), "x").output == """{"name":"fixed"}"""
  options.model = staticModel("""{"name":"valid"}""")
  assert runAgent(options, newSession("s1"), "x").output == """{"name":"valid"}"""
  options.model = staticModel("{}")
  options.structuredOutput = some(structuredOutput(schema, 0))
  try:
    discard runAgent(options, newSession("s1"), "x")
    assert false
  except PraxoError as error:
    assert errorCode(error) == "AGENT_STRUCTURED_OUTPUT"
  assert sink.kinds == @["run.started", "run.completed", "run.started", "run.completed",
                         "run.started", "run.completed", "run.started", "run.failed"]

proc testAgentCallLimits() =
  var modelCalls = 0
  let tool = newTool("echo", "Echo")
  let model = callbackModel(proc(request: Request): Response =
    inc modelCalls
    return newResponse(newMessageAssistant("", @[
      newToolCall("c1", "echo"), newToolCall("c2", "echo")]))
  )
  let sink = newSink()
  var options = newAgentOptions(model)
  options.tools = @[tool]
  options.events = sink
  options.toolCallLimit = 1
  for run in 1 .. 2:
    try:
      discard runAgent(options, newSession("s1"), "x")
      assert false
    except PraxoError as error:
      assert errorCode(error) == "AGENT_TOOL_CALL_LIMIT"
    assert modelCalls == run and tool.calls == run
  assert sink.kinds == @["run.started", "tool.call", "run.failed",
                         "run.started", "tool.call", "run.failed"]
  options.toolCallLimit = 0
  options.modelCallLimit = 1
  options.model = callbackModel(proc(request: Request): Response =
    inc modelCalls
    return newResponse(newMessageAssistant("", @[newToolCall("c1", "echo")]))
  )
  for run in 1 .. 2:
    try:
      discard runAgent(options, newSession("s1"), "x")
      assert false
    except PraxoError as error:
      assert errorCode(error) == "AGENT_MODEL_CALL_LIMIT"
    assert modelCalls == 2 + run and tool.calls == 2 + run
  options.modelCallLimit = 0
  options.model = staticModel("done")
  assert runAgent(options, newSession("s1"), "x").output == "done"

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
testRunIds()
testAgentTool()
testCallbackModel()
testCallbackErrors()
testAgentToolSelection()
testAgentPii()
testAgentStructuredOutput()
testAgentCallLimits()

proc testOpenAICompatible() =
  var capturedPath = ""
  var captured: JsonNode
  let adapter = newOpenAICompatible(
    baseUrl = "http://example.test/v1",
    model = "test-model",
    transport = proc(path: string, payload: JsonNode): JsonNode =
      capturedPath = path
      captured = payload
      return parseJsonText("""{
        "choices": [{
          "message": {
            "role": "assistant",
            "content": "",
            "tool_calls": [{
              "id": "call-1",
              "type": "function",
              "function": {"name": "echo", "arguments": "{\"text\":\"hi\"}"}
            }]
          },
          "finish_reason": "tool_calls"
        }],
        "usage": {"prompt_tokens": 3, "completion_tokens": 2}
      }""")
  )
  var request = newRequest(@[newMessage(ROLE_USER, "hello")],
                           @[newToolSpec("echo", "Echo")])
  request.toolChoice = "auto"
  let response = adapter.generate(request)
  assert capturedPath == "/chat/completions"
  assert getString(captured, "model") == "test-model"
  assert captured["messages"][0]["content"].getStr() == "hello"
  assert captured["tools"][0]["function"]["name"].getStr() == "echo"
  assert captured["tool_choice"].getStr() == "auto"
  assert response.message.toolCalls.len == 1
  assert response.message.toolCalls[0].name == "echo"
  assert response.message.toolCalls[0].arguments["text"].getStr() == "hi"
  assert response.usage.inputTokens == 3
  assert response.usage.outputTokens == 2
  let assistant = newMessageAssistant("", @[newToolCall("c1", "echo", %*{"text": "bye"})])
  discard adapter.generate(newRequest(@[assistant]))
  assert captured["messages"][0]["tool_calls"][0]["function"]["arguments"].getStr() ==
    """{"text":"bye"}"""

proc testAnthropicCompatible() =
  var capturedPath = ""
  var captured: JsonNode
  let adapter = newAnthropicCompatible(
    baseUrl = "http://example.test",
    model = "claude-test",
    apiKey = "ak",
    transport = proc(path: string, payload: JsonNode): JsonNode =
      capturedPath = path
      captured = payload
      return parseJsonText("""{"content":[{"type":"text","text":"hello"},
        {"type":"tool_use","id":"tool-1","name":"echo",
        "input":{"text":"hi"}}],"stop_reason":"end_turn",
        "usage":{"input_tokens":3,"output_tokens":4,
        "cache_read_input_tokens":2}}""")
  )
  var request = newRequest(@[newMessage(ROLE_SYSTEM, "be brief"),
                             newMessage(ROLE_USER, "hi")],
                           @[newToolSpec("echo", "Echo")])
  request.toolChoice = "auto"
  let response = adapter.generate(request)
  assert capturedPath == "/v1/messages"
  assert getString(captured, "system") == "be brief"
  assert captured["tools"][0]["input_schema"]["type"].getStr() == "object"
  assert response.message.content == "hello"
  assert response.message.toolCalls[0].id == "tool-1"
  assert response.message.toolCalls[0].arguments["text"].getStr() == "hi"
  assert response.usage.inputTokens == 3

proc testGeminiCompatible() =
  var capturedPath = ""
  var captured: JsonNode
  let adapter = newGeminiCompatible(
    baseUrl = "http://example.test",
    model = "gemini-test",
    apiKey = "gk",
    transport = proc(path: string, payload: JsonNode): JsonNode =
      capturedPath = path
      captured = payload
      return parseJsonText("""{"candidates":[{"content":{"parts":[
        {"text":"hello"},
        {"functionCall":{"name":"echo","args":{"text":"hi"}}}]},
        "finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,
        "candidatesTokenCount":4}}""")
  )
  var request = newRequest(@[newMessage(ROLE_SYSTEM, "be brief"),
                             newMessage(ROLE_USER, "hi")],
                           @[newToolSpec("echo", "Echo")])
  request.toolChoice = "auto"
  let response = adapter.generate(request)
  assert capturedPath.contains(":generateContent")
  assert captured["system_instruction"]["parts"][0]["text"].getStr() == "be brief"
  assert captured["toolConfig"]["functionCallingConfig"]["mode"].getStr() == "AUTO"
  assert response.message.content == "hello"
  assert response.message.toolCalls[0].name == "echo"

proc testHarmovelaSink() =
  var capturedPath = ""
  var capturedBody = ""
  var capturedHeaders: seq[(string, string)] = @[]
  let sink = newHarmovelaSink(
    baseUrl = "http://example.test/aep/api/",
    clock = proc(): Time = initTime(1_700_000_000'i64, 123_456_789),
    transport = proc(path: string, body: string,
                     headers: seq[(string, string)]): HarmovelaResponse =
      capturedPath = path
      capturedBody = body
      capturedHeaders = headers
      return HarmovelaResponse(status: 200, body: ""),
  )
  let event = newEvent("tool.call", "s1", "run-123", %*{"name": "echo"})
  sink.emit(event)
  assert capturedPath == "/events"
  assert capturedHeaders.len == 1
  assert capturedHeaders[0][0] == "content-type"
  assert capturedHeaders[0][1] == "application/json"
  let envelope = parseJsonText(capturedBody)
  assert getString(envelope, "spec_version") == "0.2"
  assert getString(envelope, "id") == "run-123-1700000000123456789"
  assert getString(envelope, "type") == "tool.call"
  assert getString(envelope, "source") == "praxo-core"
  assert getString(envelope, "created_at") == "2023-11-14T22:13:20.123456789Z"
  let payload = getNode(envelope, "payload")
  assert getString(payload, "name") == "echo"
  assert getString(payload, "session_id") == "s1"
  assert getString(payload, "run_id") == "run-123"

  let failed = newHarmovelaSink(
    baseUrl = "http://example.test/aep/api",
    clock = proc(): Time = initTime(1_700_000_000'i64, 123_456_789),
    transport = proc(path: string, body: string,
                     headers: seq[(string, string)]): HarmovelaResponse =
      return HarmovelaResponse(status: 500, body: "boom"),
  )
  var caught = ""
  try:
    failed.emit(event)
  except PraxoError as error:
    caught = errorCode(error)
    assert error.msg.contains("500")
    assert error.msg.contains("boom")
  assert caught == "HARMOVELA_HTTP"

proc testOtelSink() =
  var capturedEndpoint = ""
  var capturedBody = ""
  var capturedHeaders: seq[(string, string)] = @[]
  let sink = newOtelSink(
    endpoint = "https://otel.test/v1/traces",
    allowedDataKeys = @["name"],
    clock = proc(): Time = initTime(1_794_294_000'i64, 0),
    transport = proc(endpoint: string, body: string,
                     headers: seq[(string, string)]): OtelResponse =
      capturedEndpoint = endpoint
      capturedBody = body
      capturedHeaders = headers
      return OtelResponse(status: 200, body: ""),
  )
  let event = newEvent("tool.call", "s1", "run-123",
                       %*{"name": "echo", "secret": "hidden"})
  sink.emit(event)
  assert capturedEndpoint == "https://otel.test/v1/traces"
  assert capturedHeaders.len == 1
  assert capturedHeaders[0][0] == "content-type"
  assert capturedHeaders[0][1] == "application/json"
  let envelope = parseJsonText(capturedBody)
  let resource = envelope["resourceSpans"][0]
  let scope = resource["scopeSpans"][0]
  let span = scope["spans"][0]
  assert getString(span, "name") == "praxo.tool.call"
  assert getString(span, "traceId").len == 32
  assert getString(span, "spanId").len == 16
  assert getString(span, "startTimeUnixNano") == "1794294000000000000"
  var keys: seq[string] = @[]
  for item in span["attributes"]:
    keys.add(getString(item, "key"))
  assert "praxo.event.data.name" in keys
  assert "praxo.event.data.secret" notin keys
  let firstBody = capturedBody
  sink.emit(event)
  assert capturedBody == firstBody

  let missing = newOtelSink(endpoint = "")
  var missingCode = ""
  try:
    missing.emit(event)
  except PraxoError as error:
    missingCode = errorCode(error)
  assert missingCode == "OTEL_URL"

  let failed = newOtelSink(
    endpoint = "https://otel.test/v1/traces",
    transport = proc(endpoint: string, body: string,
                     headers: seq[(string, string)]): OtelResponse =
      return OtelResponse(status: 503, body: "unavailable"),
  )
  var caught = ""
  try:
    failed.emit(event)
  except PraxoError as error:
    caught = errorCode(error)
    assert error.msg.contains("503")
    assert error.msg.contains("unavailable")
  assert caught == "OTEL_HTTP"

  let longFailed = newOtelSink(
    endpoint = "https://otel.test/v1/traces",
    transport = proc(endpoint: string, body: string,
                     headers: seq[(string, string)]): OtelResponse =
      return OtelResponse(status: 500, body: "x".repeat(600)),
  )
  var longCaught = ""
  try:
    longFailed.emit(event)
  except PraxoError as error:
    longCaught = errorCode(error)
    assert error.msg.len < 600
  assert longCaught == "OTEL_HTTP"

proc testRetriever() =
  let retriever = newFuncRetriever(
    proc(query: string, limit: int): seq[Document] =
      return @[newDocument("doc-1", query & ":" & $limit)]
  )
  let documents = retrieveDocuments(retriever.retrieve, "hello", 3)
  assert documents.len == 1
  assert documents[0].id == "doc-1"
  assert documents[0].content == "hello:3"
  assert retrieveDocuments(retriever, "hello", 2)[0].content == "hello:2"
  var caught = ""
  try:
    discard retrieveDocuments(retriever.retrieve, "hello", -1)
  except PraxoError as error:
    caught = errorCode(error)
  assert caught == "RETRIEVER_INVALID"

proc testDelegation() =
  let request = newSubagentRequest("parent", "child", "look up", "fork")
  let clock = proc(): Time = initTime(1_700_000_000'i64, 123_456_789)
  let runner = proc(request: SubagentRequest): SubagentResult =
    return newSubagentResult(agentId = request.agentId, output = "done")
  let task = subagentRun(runner, request, clock)
  assert task.status == "completed"
  assert task.mode == "fork"
  assert task.output == "done"
  assert task.error == ""
  assert task.createdAt == "2023-11-14T22:13:20.123456789Z"

  let failing = proc(request: SubagentRequest): SubagentResult =
    raisePraxo("BOOM", "boom")
  let failed = subagentRun(failing, request)
  assert failed.status == "failed"
  assert failed.error == "BOOM"

  let generic = proc(request: SubagentRequest): SubagentResult =
    raise newException(ValueError, "bad")
  let genericTask = subagentRun(generic, request)
  assert genericTask.status == "failed"
  assert genericTask.error == "SUBAGENT_ERROR"

  var caught = ""
  try:
    discard subagentRun(runner, newSubagentRequest("", "child", "look up"))
  except PraxoError as error:
    caught = errorCode(error)
  assert caught == "SUBAGENT_INVALID"

testOpenAICompatible()
testAnthropicCompatible()
testGeminiCompatible()
testHarmovelaSink()
testOtelSink()
testRetriever()
testDelegation()
echo "nim tests passed"
