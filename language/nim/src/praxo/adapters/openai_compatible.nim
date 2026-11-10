import std/[httpclient, json, strutils]
import ../errors, ../jsonutil, ../models, ../agent

type
  Transport* = proc(path: string, payload: JsonNode): JsonNode {.closure.}
  OpenAICompatible* = ref object
    baseUrl*: string
    model*: string
    apiKey*: string
    transport*: Transport
    timeoutMs*: int

proc newOpenAICompatible*(baseUrl: string, model: string, apiKey: string = "",
                          transport: Transport = nil,
                          timeoutMs: int = 60000): OpenAICompatible =
  OpenAICompatible(
    baseUrl: baseUrl.strip(chars = {'/'}),
    model: model,
    apiKey: apiKey,
    transport: transport,
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

proc generate*(adapter: OpenAICompatible, request: Request): models.Response =
  let body = adapter.payload(request)
  let data = if adapter.transport != nil:
      adapter.transport("/chat/completions", body)
    else:
      adapter.post("/chat/completions", body)
  return parseResponse(data)

proc openaiModel*(adapter: OpenAICompatible): Model =
  return callbackModel(proc(request: Request): models.Response = adapter.generate(request))
