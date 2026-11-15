import std/json

import ./models

const
  INTERRUPT_APPROVE* = "approve"
  INTERRUPT_EDIT* = "edit"
  INTERRUPT_REJECT* = "reject"
  INTERRUPT_RESPOND* = "respond"

type
  Interrupt* = object
    runId*: string
    sessionId*: string
    call*: ToolCall

  InterruptDecision* = object
    action*: string
    arguments*: JsonNode
    response*: string
    reason*: string

  InterruptHandler* = proc(interrupt: Interrupt): InterruptDecision {.closure.}
  InterruptApproval* = proc(interrupt: Interrupt): bool {.closure.}

proc newInterrupt*(runId: string, sessionId: string, call: ToolCall): Interrupt =
  return Interrupt(runId: runId, sessionId: sessionId, call: call)

proc newInterruptDecision*(action: string, arguments: JsonNode = nil,
                           response: string = "",
                           reason: string = ""): InterruptDecision =
  return InterruptDecision(
    action: action,
    arguments: arguments,
    response: response,
    reason: reason
  )
