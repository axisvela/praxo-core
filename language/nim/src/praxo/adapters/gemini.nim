import std/[httpclient, json, strutils, tables]
import ../errors, ../jsonutil, ../models, ../agent

type
  GeminiTransport* = proc(path: string, payload: JsonNode): JsonNode {.closure.}
  GeminiCompatible* = ref object
    baseUrl*: string
    model*: string
    apiKey*: string
    maxOutputTokens*: int
    transport*: GeminiTransport
    timeoutMs*: int

proc newGeminiCompatible*(baseUrl: string, model: string, apiKey: string = "",
                          maxOutputTokens: int = 0,
                          transport: GeminiTransport = nil,
                          timeoutMs: int = 60000): GeminiCompatible =
  GeminiCompatible(
    baseUrl: baseUrl.strip(chars = {'/'}),
    model: model,
    apiKey: apiKey,
    maxOutputTokens: maxOutputTokens,
    transport: transport,
    timeoutMs: timeoutMs,
  )

proc messageParts(message: Message): JsonNode =
  result = newJArray()
  if message.content.len > 0:
    result.add(%*{"text": message.content})
  for item in message.contentBlocks:
    if item.kind == "text" and item.text.len > 0:
      result.add(%*{"text": item.text})
  for call in message.toolCalls:
    result.add(%*{"functionCall": {
      "name": call.name,
      "args": (if call.arguments.isNil: newJObject() else: call.arguments),
    }})

proc payload(adapter: GeminiCompatible, request: Request): JsonNode =
  var system = newJArray()
  var contents = newJArray()
  var pending = newJArray()
  var names = initTable[string, string]()
  proc flush() =
    if pending.len > 0:
      contents.add(%*{"role": "user", "parts": pending})
      pending = newJArray()
  for message in request.messages:
    if message.role == ROLE_SYSTEM:
      if message.content.len > 0:
        system.add(%*{"text": message.content})
    elif message.role == ROLE_TOOL:
      let name = if names.hasKey(message.toolId): names[message.toolId]
                 elif message.toolId.len > 0: message.toolId else: "tool"
      pending.add(%*{"functionResponse": {
        "name": name,
        "response": {"result": message.content},
      }})
    else:
      flush()
      let parts = messageParts(message)
      if parts.len > 0:
        let role = if message.role == ROLE_ASSISTANT: "model" else: "user"
        contents.add(%*{"role": role, "parts": parts})
      for call in message.toolCalls:
        if call.id.len > 0 and call.name.len > 0:
          names[call.id] = call.name
  flush()
  result = %*{"contents": contents}
  if system.len > 0:
    result["system_instruction"] = %*{"parts": system}
  if request.tools.len > 0:
    var declarations = newJArray()
    for item in request.tools:
      declarations.add(%*{
        "name": item.name,
        "description": item.description,
        "parameters": {"type": "object"},
      })
    result["tools"] = %*[{"functionDeclarations": declarations}]
    let mode = if request.toolChoice == "required": "ANY"
               elif request.toolChoice == "none": "NONE" else: "AUTO"
    result["toolConfig"] = %*{"functionCallingConfig": {"mode": mode}}
  if adapter.maxOutputTokens > 0:
    result["generationConfig"] = %*{"maxOutputTokens": adapter.maxOutputTokens}

proc parseResponse(data: JsonNode): models.Response =
  if data.hasKey("error"):
    raisePraxo("PROVIDER_HTTP", "gemini: provider error")
  if not data.hasKey("candidates") or data["candidates"].kind != JArray or
      data["candidates"].len == 0:
    raisePraxo("PROVIDER_HTTP", "gemini: empty response")
  let candidate = data["candidates"][0]
  var content = ""
  var toolCalls: seq[ToolCall] = @[]
  if candidate.hasKey("content") and candidate["content"].kind == JObject and
      candidate["content"].hasKey("parts"):
    for part in candidate["content"]["parts"]:
      if part.kind != JObject: continue
      if part.hasKey("text") and part["text"].kind == JString:
        content.add(part["text"].getStr())
      if part.hasKey("functionCall") and part["functionCall"].kind == JObject:
        let call = part["functionCall"]
        toolCalls.add(newToolCall(
          id = "call-" & $(toolCalls.len + 1),
          name = getString(call, "name"),
          arguments = if call.hasKey("args") and call["args"].kind == JObject:
              call["args"] else: newJObject(),
        ))
  var inputTokens = 0
  var outputTokens = 0
  if data.hasKey("usageMetadata") and data["usageMetadata"].kind == JObject:
    inputTokens = getInt(data["usageMetadata"], "promptTokenCount", 0)
    outputTokens = getInt(data["usageMetadata"], "candidatesTokenCount", 0)
  newResponse(newMessageAssistant(content, toolCalls),
              newUsage(inputTokens, outputTokens))

proc post(adapter: GeminiCompatible, path: string, body: JsonNode): JsonNode =
  if adapter.baseUrl.len == 0:
    raisePraxo("PROVIDER_HTTP", "provider base URL is required")
  let client = newHttpClient(timeout = adapter.timeoutMs)
  defer: client.close()
  client.headers = newHttpHeaders({
    "Content-Type": "application/json",
    "x-goog-api-key": adapter.apiKey,
  })
  let response = client.request(adapter.baseUrl & path, httpMethod = HttpPost,
                                body = encodeJson(body))
  if response.code.int < 200 or response.code.int >= 300:
    raisePraxo("PROVIDER_HTTP",
      "provider returned HTTP " & $response.code.int & ": " & response.body)
  parseJsonText(response.body)

proc generate*(adapter: GeminiCompatible, request: Request): models.Response =
  if adapter.apiKey.len == 0:
    raisePraxo("MODEL_CONFIG", "gemini: API key is required")
  if adapter.model.len == 0:
    raisePraxo("MODEL_CONFIG", "gemini: model is required")
  let body = adapter.payload(request)
  let path = "/v1beta/models/" & adapter.model & ":generateContent"
  let data = if adapter.transport != nil:
      adapter.transport(path, body)
    else:
      adapter.post(path, body)
  parseResponse(data)

proc geminiModel*(adapter: GeminiCompatible): Model =
  callbackModel(proc(request: Request): models.Response = adapter.generate(request))
