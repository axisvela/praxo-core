import std/[httpclient, json, strutils]
import ../errors, ../jsonutil, ../models, ../agent

type
  AnthropicTransport* = proc(path: string, payload: JsonNode): JsonNode {.closure.}
  AnthropicCompatible* = ref object
    baseUrl*: string
    model*: string
    apiKey*: string
    version*: string
    maxTokens*: int
    transport*: AnthropicTransport
    timeoutMs*: int

proc newAnthropicCompatible*(baseUrl: string, model: string,
                             apiKey: string = "",
                             version: string = "2023-06-01",
                             maxTokens: int = 1024,
                             transport: AnthropicTransport = nil,
                             timeoutMs: int = 60000): AnthropicCompatible =
  AnthropicCompatible(
    baseUrl: baseUrl.strip(chars = {'/'}),
    model: model,
    apiKey: apiKey,
    version: version,
    maxTokens: maxTokens,
    transport: transport,
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
  callbackModel(proc(request: Request): models.Response = adapter.generate(request))
