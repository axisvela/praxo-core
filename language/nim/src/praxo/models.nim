import std/json

const
  ROLE_SYSTEM* = "system"
  ROLE_USER* = "user"
  ROLE_ASSISTANT* = "assistant"
  ROLE_TOOL* = "tool"

let streamKinds* = @["values", "updates", "messages", "tasks", "debug", "checkpoint"]

type
  ContentBlock* = object
    kind*: string
    text*: string
    imageUrl*: string
    data*: string

  ToolCall* = object
    id*: string
    name*: string
    arguments*: JsonNode

  Message* = object
    role*: string
    content*: string
    contentBlocks*: seq[ContentBlock]
    toolCalls*: seq[ToolCall]
    toolId*: string

  ToolSpec* = object
    name*: string
    description*: string

  Usage* = object
    inputTokens*: int
    outputTokens*: int

  Request* = object
    messages*: seq[Message]
    tools*: seq[ToolSpec]
    toolChoice*: string

  Response* = object
    message*: Message
    usage*: Usage

  Session* = object
    id*: string
    messages*: seq[Message]

  RunResult* = object
    runId*: string
    output*: string
    steps*: int
    usage*: Usage

  MemoryRecord* = object
    id*: string
    frame*: string
    content*: string
    createdAt*: string

  PathGrant* = object
    root*: string
    access*: string

  Decision* = object
    allowed*: bool
    reason*: string

  Action* = object
    kind*: string
    sessionId*: string
    toolName*: string
    arguments*: JsonNode

  ContextBudget* = object
    maxTokens*: int
    keepRecent*: int

  Event* = object
    kind*: string
    sessionId*: string
    runId*: string
    data*: JsonNode

proc newToolCall*(id: string, name: string, arguments: JsonNode = nil): ToolCall =
  ToolCall(id: id, name: name, arguments: if arguments.isNil: newJObject() else: arguments)

proc newMessage*(role: string, content: string): Message =
  Message(role: role, content: content)

proc newMessageAssistant*(content: string, toolCalls: seq[ToolCall] = @[]): Message =
  Message(role: ROLE_ASSISTANT, content: content, toolCalls: toolCalls)

proc newMessageTool*(content: string, toolId: string): Message =
  Message(role: ROLE_TOOL, content: content, toolId: toolId)

proc newToolSpec*(name: string, description: string): ToolSpec =
  ToolSpec(name: name, description: description)

proc newUsage*(inputTokens: int = 0, outputTokens: int = 0): Usage =
  Usage(inputTokens: inputTokens, outputTokens: outputTokens)

proc addUsage*(left: Usage, right: Usage): Usage =
  Usage(
    inputTokens: left.inputTokens + right.inputTokens,
    outputTokens: left.outputTokens + right.outputTokens
  )

proc newRequest*(messages: seq[Message], tools: seq[ToolSpec] = @[]): Request =
  Request(messages: messages, tools: tools)

proc newResponse*(message: Message, usage: Usage = Usage()): Response =
  Response(message: message, usage: usage)

proc newSession*(id: string, messages: seq[Message] = @[]): Session =
  Session(id: id, messages: messages)

proc newRunResult*(runId: string, output: string, steps: int, usage: Usage): RunResult =
  RunResult(runId: runId, output: output, steps: steps, usage: usage)

proc newMemoryRecord*(id: string, frame: string, content: string, createdAt: string = ""): MemoryRecord =
  MemoryRecord(id: id, frame: frame, content: content, createdAt: createdAt)

proc newPathGrant*(root: string, access: string = "read"): PathGrant =
  PathGrant(root: root, access: access)

proc newDecision*(allowed: bool, reason: string = ""): Decision =
  Decision(allowed: allowed, reason: reason)

proc newAction*(kind: string, sessionId: string, toolName: string = "",
                arguments: JsonNode = nil): Action =
  Action(kind: kind, sessionId: sessionId, toolName: toolName,
         arguments: if arguments.isNil: newJObject() else: arguments)

proc newContextBudget*(maxTokens: int, keepRecent: int): ContextBudget =
  ContextBudget(maxTokens: maxTokens, keepRecent: keepRecent)

proc newEvent*(kind: string, sessionId: string, runId: string = "",
               data: JsonNode = nil): Event =
  Event(kind: kind, sessionId: sessionId, runId: runId,
        data: if data.isNil: newJNull() else: data)

proc messageWire*(value: Message): JsonNode =
  result = newJObject()
  result["role"] = %value.role
  if value.content.len > 0 or
      (value.contentBlocks.len == 0 and value.toolCalls.len == 0 and value.toolId.len == 0):
    result["content"] = %value.content
  if value.contentBlocks.len > 0:
    var blocks = newJArray()
    for entry in value.contentBlocks:
      var wire = newJObject()
      wire["type"] = %entry.kind
      if entry.text.len > 0:
        wire["text"] = %entry.text
      if entry.imageUrl.len > 0:
        wire["image_url"] = %entry.imageUrl
      if entry.data.len > 0:
        wire["data"] = %entry.data
      blocks.add(wire)
    result["contentBlocks"] = blocks
  if value.toolCalls.len > 0:
    var calls = newJArray()
    for call in value.toolCalls:
      var wire = newJObject()
      wire["id"] = %call.id
      wire["name"] = %call.name
      wire["arguments"] = if call.arguments.isNil: newJObject() else: call.arguments
      calls.add(wire)
    result["toolCalls"] = calls
  if value.toolId.len > 0:
    result["toolId"] = %value.toolId
