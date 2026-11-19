import std/[algorithm, httpclient, json, sequtils, strutils, tables]
import ../errors, ../jsonutil, ../models, ../agent

type
  Transport* = proc(path: string, payload: JsonNode): JsonNode {.closure.}
  StreamTransport* = proc(path: string, payload: JsonNode): string {.closure.}
  OpenAICompatible* = ref object
    baseUrl*: string
    model*: string
    apiKey*: string
    transport*: Transport
    streamTransport*: StreamTransport
    timeoutMs*: int

proc newOpenAICompatible*(baseUrl: string, model: string, apiKey: string = "",
                          transport: Transport = nil,
                          streamTransport: StreamTransport = nil,
                          timeoutMs: int = 60000): OpenAICompatible =
  OpenAICompatible(
    baseUrl: baseUrl.strip(chars = {'/'}),
    model: model,
    apiKey: apiKey,
    transport: transport,
    streamTransport: streamTransport,
    timeoutMs: timeoutMs,
  )

proc messagePayload(message: Message): JsonNode =
  var content = message.content
  if content.len == 0 and message.contentBlocks.len > 0:
    var parts: seq[string] = @[]
    for item in message.contentBlocks:
      if item.kind == "text" and item.text.len > 0:
        parts.add(item.text)
    content = parts.join("")
  result = %*{"role": message.role, "content": content}
  if message.role == ROLE_ASSISTANT and message.toolCalls.len > 0:
    var calls = newJArray()
    for call in message.toolCalls:
      calls.add(%*{
        "id": call.id,
        "type": "function",
        "function": {
          "name": call.name,
          "arguments": encodeJson(if call.arguments.isNil: newJObject() else: call.arguments),
        },
      })
    result["tool_calls"] = calls
  if message.role == ROLE_TOOL and message.toolId.len > 0:
    result["tool_call_id"] = %message.toolId

proc payload(adapter: OpenAICompatible, request: Request): JsonNode =
  var messages = newJArray()
  for message in request.messages:
    messages.add(messagePayload(message))
  result = %*{"model": adapter.model, "messages": messages}
  if request.tools.len > 0:
    var tools = newJArray()
    for item in request.tools:
      tools.add(%*{
        "type": "function",
        "function": {
          "name": item.name,
          "description": item.description,
          "parameters": {"type": "object"},
        },
      })
    result["tools"] = tools
  if request.toolChoice.len > 0:
    result["tool_choice"] = %request.toolChoice

proc parseResponse(data: JsonNode): models.Response =
  var choice = newJObject()
  if data.hasKey("choices") and data["choices"].kind == JArray and data["choices"].len > 0:
    choice = data["choices"][0]
  var message = newJObject()
  if choice.hasKey("message") and choice["message"].kind == JObject:
    message = choice["message"]
  var toolCalls: seq[ToolCall] = @[]
  if message.hasKey("tool_calls") and message["tool_calls"].kind == JArray:
    for item in message["tool_calls"]:
      var function = newJObject()
      if item.hasKey("function") and item["function"].kind == JObject:
        function = item["function"]
      var arguments = newJObject()
      if function.hasKey("arguments"):
        let raw = function["arguments"]
        if raw.kind == JString and raw.getStr().len > 0:
          arguments = parseJsonText(raw.getStr())
        elif raw.kind == JObject:
          arguments = raw
      toolCalls.add(newToolCall(
        id = if item.hasKey("id"): item["id"].getStr() else: "",
        name = if function.hasKey("name"): function["name"].getStr() else: "",
        arguments = arguments,
      ))
  let content = if message.hasKey("content") and message["content"].kind == JString:
      message["content"].getStr() else: ""
  var inputTokens = 0
  var outputTokens = 0
  if data.hasKey("usage") and data["usage"].kind == JObject:
    inputTokens = getInt(data["usage"], "prompt_tokens", 0)
    outputTokens = getInt(data["usage"], "completion_tokens", 0)
  return newResponse(
    newMessageAssistant(content, toolCalls),
    newUsage(inputTokens, outputTokens),
  )

proc post(adapter: OpenAICompatible, path: string, body: JsonNode): JsonNode =
  if adapter.baseUrl.len == 0:
    raisePraxo("PROVIDER_HTTP", "provider base URL is required")
  let client = newHttpClient(timeout = adapter.timeoutMs)
  defer: client.close()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})
  if adapter.apiKey.len > 0:
    client.headers["Authorization"] = "Bearer " & adapter.apiKey
  let response = client.request(adapter.baseUrl & path, httpMethod = HttpPost,
                                body = encodeJson(body))
  if response.code.int < 200 or response.code.int >= 300:
    raisePraxo("PROVIDER_HTTP",
      "provider returned HTTP " & $response.code.int & ": " & response.body)
  return parseJsonText(response.body)

proc postStream(adapter: OpenAICompatible, path: string, body: JsonNode): string =
  if adapter.baseUrl.len == 0:
    raisePraxo("PROVIDER_HTTP", "provider base URL is required")
  let client = newHttpClient(timeout = adapter.timeoutMs)
  defer: client.close()
  client.headers = newHttpHeaders({
    "Content-Type": "application/json",
    "Accept": "text/event-stream",
  })
  if adapter.apiKey.len > 0:
    client.headers["Authorization"] = "Bearer " & adapter.apiKey
  let response = client.request(adapter.baseUrl & path, httpMethod = HttpPost,
                                body = encodeJson(body))
  if response.code.int < 200 or response.code.int >= 300:
    raisePraxo("PROVIDER_HTTP",
      "provider returned HTTP " & $response.code.int & ": " & response.body)
  return response.body

proc parseSseResponse(text: string,
                      onDelta: proc(delta: string)): models.Response =
  var content = ""
  var inputTokens = 0
  var outputTokens = 0
  var done = false
  var calls = initTable[int, tuple[id, name, arguments: string]]()
  for raw in text.splitLines():
    let line = raw.strip()
    if not line.startsWith("data:"):
      continue
    let chunk = line[5 .. ^1].strip()
    if chunk.len == 0:
      continue
    if chunk == "[DONE]":
      done = true
      break
    let event =
      try:
        parseJsonText(chunk)
      except CatchableError:
        raisePraxo("MODEL_STREAM", "invalid SSE packet")
    let usage = getObject(event, "usage")
    if not usage.isNil:
      inputTokens = getInt(usage, "prompt_tokens", inputTokens)
      outputTokens = getInt(usage, "completion_tokens", outputTokens)
    for choice in getArray(event, "choices"):
      let delta = getObject(choice, "delta")
      if not delta.isNil:
        let piece = getString(delta, "content")
        if piece.len > 0:
          content.add(piece)
          onDelta(piece)
        for item in getArray(delta, "tool_calls"):
          let index = getInt(item, "index", calls.len)
          var slot = calls.getOrDefault(index,
            (id: "", name: "", arguments: ""))
          let id = getString(item, "id")
          if id.len > 0:
            slot.id.add(id)
          let functionValue = getObject(item, "function")
          if not functionValue.isNil:
            slot.name.add(getString(functionValue, "name"))
            slot.arguments.add(getString(functionValue, "arguments"))
          calls[index] = slot
      let reason = getString(choice, "finish_reason")
      if reason.len > 0:
        done = true
  if not done:
    raisePraxo("MODEL_STREAM", "stream ended before completion")
  var toolCalls: seq[ToolCall] = @[]
  var indexes = toSeq(calls.keys)
  indexes.sort()
  for index in indexes:
    let slot = calls[index]
    if slot.name.len == 0:
      continue
    var arguments = newJObject()
    if slot.arguments.len > 0:
      try:
        arguments = parseJsonText(slot.arguments)
      except CatchableError:
        raisePraxo("PROVIDER_JSON", "provider returned invalid tool arguments")
      if arguments.kind != JObject:
        raisePraxo("PROVIDER_JSON", "provider returned invalid tool arguments")
    toolCalls.add(newToolCall(id = slot.id, name = slot.name,
                              arguments = arguments))
  return newResponse(newMessageAssistant(content, toolCalls),
                     newUsage(inputTokens, outputTokens))

proc generate*(adapter: OpenAICompatible, request: Request): models.Response =
  let body = adapter.payload(request)
  let data = if adapter.transport != nil:
      adapter.transport("/chat/completions", body)
    else:
      adapter.post("/chat/completions", body)
  return parseResponse(data)

proc generateStream*(adapter: OpenAICompatible, request: Request,
                     onDelta: proc(delta: string)): models.Response =
  var body = adapter.payload(request)
  body["stream"] = %true
  let text = if adapter.streamTransport != nil:
      adapter.streamTransport("/chat/completions", body)
    else:
      adapter.postStream("/chat/completions", body)
  return parseSseResponse(text, onDelta)

proc openaiModel*(adapter: OpenAICompatible): Model =
  return Model(
    mode: "callback",
    invoke: proc(request: Request): models.Response = adapter.generate(request),
    stream: proc(request: Request, onDelta: proc(delta: string)): models.Response =
      adapter.generateStream(request, onDelta),
  )
