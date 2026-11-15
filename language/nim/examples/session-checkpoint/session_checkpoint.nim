import std/json
import std/options
import std/tables

import praxo/agent
import praxo/jsonutil
import praxo/models
import praxo/runtime

type
  Checkpoint* = object
    id*: string
    sessionId*: string
    runId*: string
    status*: string
    messages*: seq[Message]

  MemoryStore* = ref object
    allow: CheckpointAllowlist
    encoded: Table[string, string]

  SessionCheckpointOutcome* = object
    restored*: int
    output*: string

proc wire(checkpoint: Checkpoint): JsonNode =
  result = newJObject()
  result["id"] = %checkpoint.id
  result["sessionId"] = %checkpoint.sessionId
  result["runId"] = %checkpoint.runId
  result["status"] = %checkpoint.status
  var messages = newJArray()
  for message in checkpoint.messages:
    messages.add(messageWire(message))
  result["messages"] = messages

proc decode(node: JsonNode): Checkpoint =
  result.id = getString(node, "id")
  result.sessionId = getString(node, "sessionId")
  result.runId = getString(node, "runId")
  result.status = getString(node, "status")
  for item in getArray(node, "messages"):
    result.messages.add(newMessage(getString(item, "role"), getString(item, "content")))

proc newMemoryStore*(): MemoryStore =
  result = MemoryStore(
    allow: newCheckpointAllowlist(),
    encoded: initTable[string, string]()
  )
  result.allow.register("session")

proc save*(store: MemoryStore, checkpoint: Checkpoint) =
  store.encoded[checkpoint.sessionId] = store.allow.marshal("session", wire(checkpoint))

proc load*(store: MemoryStore, sessionId: string): Option[Checkpoint] =
  if not store.encoded.hasKey(sessionId):
    return none(Checkpoint)
  return some(decode(store.allow.unmarshal(store.encoded[sessionId])))

proc turnModel(): Model =
  return callbackModel(proc(request: Request): Response =
    newResponse(newMessageAssistant("turn " & $request.messages.len)))

proc run*(): SessionCheckpointOutcome =
  let store = newMemoryStore()
  var session = newSession("session-1", @[
    newMessage(ROLE_USER, "first"),
    newMessage(ROLE_ASSISTANT, "ack")
  ])
  store.save(Checkpoint(
    id: "cp-1",
    sessionId: session.id,
    runId: "run-1",
    status: "completed",
    messages: session.messages
  ))

  var options = newAgentOptions(turnModel())
  options.maxSteps = 2

  let first = store.load(session.id)
  if first.isNone:
    raise newException(ValueError, "checkpoint not found")
  session.messages = first.get().messages
  let second = runAgent(options, session, "second")
  if second.output != "turn 3":
    raise newException(ValueError, "unexpected second turn: " & second.output)

  session.messages.add(newMessage(ROLE_USER, "second"))
  session.messages.add(newMessage(ROLE_ASSISTANT, second.output))
  store.save(Checkpoint(
    id: "cp-2",
    sessionId: session.id,
    runId: "run-2",
    status: "completed",
    messages: session.messages
  ))

  let loaded = store.load(session.id)
  if loaded.isNone:
    raise newException(ValueError, "checkpoint not found")
  session.messages = loaded.get().messages
  let third = runAgent(options, session, "third")
  if third.output != "turn 5":
    raise newException(ValueError, "unexpected third turn: " & third.output)

  result = SessionCheckpointOutcome(
    restored: loaded.get().messages.len,
    output: third.output
  )

when isMainModule:
  let outcome = run()
  echo "restored messages: ", outcome.restored
  echo "output: ", outcome.output
