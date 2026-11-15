module Hitl

using ..Models: ToolCall

export INTERRUPT_APPROVE, INTERRUPT_EDIT, INTERRUPT_REJECT, INTERRUPT_RESPOND
export Interrupt, InterruptDecision

const INTERRUPT_APPROVE = "approve"
const INTERRUPT_EDIT = "edit"
const INTERRUPT_REJECT = "reject"
const INTERRUPT_RESPOND = "respond"

struct Interrupt
    run_id::String
    session_id::String
    call::ToolCall
end

mutable struct InterruptDecision
    action::String
    arguments::Union{Nothing,Dict{String,Any}}
    response::String
    reason::String
end

InterruptDecision(action::String; arguments=nothing, response::String="",
                  reason::String="") =
    InterruptDecision(action, arguments, response, reason)

end
