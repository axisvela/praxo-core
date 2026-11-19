import std/[algorithm, httpclient, json, sequtils, strutils, tables]
import ../errors, ../jsonutil, ../models, ../agent

type
  AnthropicTransport* = proc(path: string, payload: JsonNode): JsonNode {.closure.}
  AnthropicStreamTransport* = proc(path: string, payload: JsonNode): string {.closure.}
  AnthropicCompatible* = ref object
    baseUrl*: string
    model*: string
    apiKey*: string
    version*: string
    maxTokens*: int
    transport*: AnthropicTransport
    streamTransport*: AnthropicStreamTransport
    timeoutMs*: int

proc newAnthropicCompatible*(baseUrl: string, model: string,
                             apiKey: string = "",
                             version: string = "2023-06-01",
                             maxTokens: int = 1024,
                             transport: AnthropicTransport = nil,
                             streamTransport: AnthropicStreamTransport = nil,
                             timeoutMs: int = 60000): AnthropicCompatible =
  AnthropicCompatible(
    baseUrl: baseUrl.strip(chars = {'/'}),
    model: model,
    apiKey: apiKey,
    version: version,
    maxTokens: maxTokens,
    transport: transport,
    streamTransport: streamTransport,
    timeoutMs: timeoutMs,
  )

proc messageContent(message: Message): JsonNode =
  result = newJArray()
  if message.content.len > 0:
    result.add(%*{"type": "text", "text": message.content})
  for item in message.contentBlocks:
    if item.kind == "text" and item.text.len > 0:
      result.add(%*{"type": "text", "text": item.text})
  for call in message.toolCalls:
    result.add(%*{
      "type": "tool_use",
      "id": call.id,
      "name": call.name,
      "input": (if call.arguments.isNil: newJObject() else: call.arguments),
    })

proc payload(adapter: AnthropicCompatible, request: Request): JsonNode =
  var system = ""
  var messages = newJArray()
  var pending = newJArray()
  proc flush() =
    if pending.len > 0:
      messages.add(%*{"role": "user", "content": pending})
      pending = newJArray()
  for message in request.messages:
    if message.role == ROLE_SYSTEM:
      if message.content.len > 0:
        if system.len > 0: system.add("\n\n")
        system.add(message.content)
    elif message.role == ROLE_TOOL:
      pending.add(%*{
        "type": "tool_result",
        "tool_use_id": message.toolId,
        "content": message.content,
      })
    else:
      flush()
      let content = messageContent(message)
      if content.len > 0:
        messages.add(%*{"role": message.role, "content": content})
  flush()
  result = %*{
    "model": adapter.model,
    "max_tokens": adapter.maxTokens,
    "messages": messages,
  }
  if system.len > 0:
    result["system"] = %system
  if request.tools.len > 0:
    var tools = newJArray()
    for item in request.tools:
      tools.add(%*{
        "name": item.name,
        "description": item.description,
        "input_schema": {"type": "object"},
      })
    result["tools"] = tools
    if request.toolChoice == "auto":
      result["tool_choice"] = %*{"type": "auto"}
    elif request.toolChoice == "required":
      result["tool_choice"] = %*{"type": "any"}
    elif request.toolChoice == "none":
      result["tool_choice"] = %*{"type": "none"}

proc parseResponse(data: JsonNode): models.Response =
  if data.hasKey("error"):
    raisePraxo("PROVIDER_HTTP", "anthropic: provider error")
  var content = ""
  var toolCalls: seq[ToolCall] = @[]
  if data.hasKey("content") and data["content"].kind == JArray:
    for item in data["content"]:
      if item.kind != JObject: continue
      let kind = getString(item, "type")
      if kind == "text":
        content.add(getString(item, "text"))
      elif kind == "tool_use":
        toolCalls.add(newToolCall(
          id = getString(item, "id"),
          name = getString(item, "name"),
          arguments = if item.hasKey("input") and item["input"].kind == JObject:
              item["input"] else: newJObject(),
        ))
  var inputTokens = 0
  var outputTokens = 0
  if data.hasKey("usage") and data["usage"].kind == JObject:
    inputTokens = getInt(data["usage"], "input_tokens", 0)
    outputTokens = getInt(data["usage"], "output_tokens", 0)
  newResponse(newMessageAssistant(content, toolCalls),
              newUsage(inputTokens, outputTokens))

proc post(adapter: AnthropicCompatible, path: string, body: JsonNode): JsonNode =
  if adapter.baseUrl.len == 0:
    raisePraxo("PROVIDER_HTTP", "provider base URL is required")
  let client = newHttpClient(timeout = adapter.timeoutMs)
  defer: client.close()
  client.headers = newHttpHeaders({
    "Content-Type": "application/json",
    "x-api-key": adapter.apiKey,
    "anthropic-version": adapter.version,
  })
  let response = client.request(adapter.baseUrl & path, httpMethod = HttpPost,
                                body = encodeJson(body))
  if response.code.int < 200 or response.code.int >= 300:
    raisePraxo("PROVIDER_HTTP",
      "provider returned HTTP " & $response.code.int & ": " & response.body)
  parseJsonText(response.body)

proc postStream(adapter: AnthropicCompatible, path: string,
                body: JsonNode): string =
  if adapter.baseUrl.len == 0:
    raisePraxo("PROVIDER_HTTP", "provider base URL is required")
  let client = newHttpClient(timeout = adapter.timeoutMs)
  defer: client.close()
  client.headers = newHttpHeaders({
    "Content-Type": "application/json",
    "Accept": "text/event-stream",
    "x-api-key": adapter.apiKey,
    "anthropic-version": adapter.version,
  })
  let response = client.request(adapter.baseUrl & path, httpMethod = HttpPost,
                                body = encodeJson(body))
  if response.code.int < 200 or response.code.int >= 300:
    raisePraxo("PROVIDER_HTTP",
      "provider returned HTTP " & $response.code.int & ": " & response.body)
  return response.body

proc parseSseResponse(text: string,
                      onDelta: proc(delta: string)): models.Response =
  var content = ""
  var calls = initTable[int, tuple[id, name, arguments: string]]()
  var inputTokens = 0
  var outputTokens = 0
  var stopReason = ""
  var stopped = false
  for raw in text.splitLines():
    let line = raw.strip()
    if not line.startsWith("data:"):
      continue
    let chunk = line[5 .. ^1].strip()
    if chunk.len == 0:
      continue
    let event =
      try:
        parseJsonText(chunk)
      except CatchableError:
        raisePraxo("MODEL_STREAM", "anthropic: invalid stream chunk")
    let kind = getString(event, "type")
    case kind
    of "message_start":
      let usage = getObject(getObject(event, "message"), "usage")
      if not usage.isNil:
        inputTokens = getInt(usage, "input_tokens", inputTokens)
    of "content_block_start":
      let index = getInt(event, "index", calls.len)
      let contentBlock = getObject(event, "content_block")
      if not contentBlock.isNil and getString(contentBlock, "type") == "tool_use":
        calls[index] = (id: getString(contentBlock, "id"),
                        name: getString(contentBlock, "name"), arguments: "")
    of "content_block_delta":
      let index = getInt(event, "index", 0)
      let delta = getObject(event, "delta")
      if not delta.isNil:
        let deltaType = getString(delta, "type")
        if deltaType == "text_delta":
          let piece = getString(delta, "text")
          if piece.len > 0:
            content.add(piece)
            onDelta(piece)
        elif deltaType == "input_json_delta" and calls.hasKey(index):
          var call = calls[index]
          call.arguments.add(getString(delta, "partial_json"))
          calls[index] = call
    of "message_delta":
      let delta = getObject(event, "delta")
      if not delta.isNil:
        let reason = getString(delta, "stop_reason")
        if reason.len > 0:
          stopReason = reason
      let usage = getObject(event, "usage")
      if not usage.isNil:
        outputTokens = getInt(usage, "output_tokens", outputTokens)
    of "message_stop":
      stopped = true
    of "error":
      raisePraxo("MODEL_STREAM", "anthropic: stream error")
    else:
      discard
  if not stopped and stopReason.len == 0:
    raisePraxo("MODEL_STREAM", "anthropic: stream ended before completion")
  var toolCalls: seq[ToolCall] = @[]
  var indexes = toSeq(calls.keys)
  indexes.sort()
  for index in indexes:
    let call = calls[index]
    if call.name.len == 0:
      continue
    var arguments = newJObject()
    if call.arguments.len > 0:
      try:
        arguments = parseJsonText(call.arguments)
      except CatchableError:
        raisePraxo("PROVIDER_JSON", "anthropic: invalid tool arguments")
      if arguments.kind != JObject:
        raisePraxo("PROVIDER_JSON", "anthropic: invalid tool arguments")
    toolCalls.add(newToolCall(id = call.id, name = call.name,
                              arguments = arguments))
  let response = newResponse(newMessageAssistant(content, toolCalls),
                             newUsage(inputTokens, outputTokens))
  return response

proc generateStream*(adapter: AnthropicCompatible, request: Request,
                     onDelta: proc(delta: string)): models.Response =
  if adapter.apiKey.len == 0:
    raisePraxo("MODEL_CONFIG", "anthropic: API key is required")
  if adapter.model.len == 0:
    raisePraxo("MODEL_CONFIG", "anthropic: model is required")
  var body = adapter.payload(request)
  body["stream"] = %true
  let text = if adapter.streamTransport != nil:
      adapter.streamTransport("/v1/messages", body)
    else:
      adapter.postStream("/v1/messages", body)
  return parseSseResponse(text, onDelta)

proc generate*(adapter: AnthropicCompatible, request: Request): models.Response =
  if adapter.apiKey.len == 0:
    raisePraxo("MODEL_CONFIG", "anthropic: API key is required")
  if adapter.model.len == 0:
    raisePraxo("MODEL_CONFIG", "anthropic: model is required")
  let body = adapter.payload(request)
  let data = if adapter.transport != nil:
      adapter.transport("/v1/messages", body)
    else:
      adapter.post("/v1/messages", body)
  parseResponse(data)

proc anthropicModel*(adapter: AnthropicCompatible): Model =
  return Model(
    mode: "callback",
    invoke: proc(request: Request): models.Response = adapter.generate(request),
    stream: proc(request: Request, onDelta: proc(delta: string)): models.Response =
      adapter.generateStream(request, onDelta),
  )
