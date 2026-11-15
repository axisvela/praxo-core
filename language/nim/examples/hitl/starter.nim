import std/json

import praxo

type
  WriteNoteLog = ref object
    notes: seq[string]

proc fixtureModel(): Model =
  var calls = 0
  return callbackModel(proc(request: Request): Response =
    inc calls
    if calls > 1:
      return newResponse(newMessageAssistant("done"))
    let call = newToolCall("write-note-1", "write_note",
                           %*{"text": "hello", "visibility": "public"})
    return newResponse(newMessageAssistant("", @[call])))

proc allowPublic(action: Action): Decision =
  if action.kind == "model.generate":
    return newDecision(true)
  if action.kind == "tool.invoke":
    return newDecision(action.toolName == "write_note" and
                       getString(action.arguments, "visibility") == "public",
                       "only public notes are permitted")
  return newDecision(false, "unsupported action")

proc buildAgent(handler: InterruptHandler): tuple[options: AgentOptions,
                                                   effects: WriteNoteLog] =
  let effects = WriteNoteLog()
  let tool = newTool("write_note",
                     "Write a short note with the requested visibility.",
                     proc(arguments: JsonNode): JsonNode =
    effects.notes.add(getString(arguments, "text"))
    return %"written")
  var options = newAgentOptions(fixtureModel())
  options.tools = @[tool]
  options.allowedTools = @["write_note"]
  options.policy = allowPublic
  options.interruptOn = @["write_note"]
  options.onInterruptDecision = handler
  options.maxSteps = 3
  return (options, effects)

proc run*(): seq[string] =
  var approve = buildAgent(proc(interrupt: Interrupt): InterruptDecision =
    return newInterruptDecision(INTERRUPT_APPROVE))
  let approved = runAgent(approve.options, newSession("hitl-approve"),
                          "Write a note.")
  if approved.output != "done" or approve.effects.notes.len != 1:
    raise newException(ValueError,
      "approve scenario failed: output=" & approved.output &
      " effects=" & $approve.effects.notes.len)
  result.add("approve: written; effects=1")

  var edit = buildAgent(proc(interrupt: Interrupt): InterruptDecision =
    return newInterruptDecision(INTERRUPT_EDIT,
                                %*{"text": "hello", "visibility": "private"}))
  var denied = false
  try:
    discard runAgent(edit.options, newSession("hitl-edit"), "Write a note.")
  except PraxoError as error:
    if errorCode(error) != "AGENT_POLICY_DENIED" or edit.effects.notes.len != 0:
      raise newException(ValueError,
        "edit scenario failed: effects=" & $edit.effects.notes.len)
    denied = true
  if not denied:
    raise newException(ValueError, "edited private note was not denied")
  result.add("edit: policy rejected; effects=0")

when isMainModule:
  for line in run():
    echo line
