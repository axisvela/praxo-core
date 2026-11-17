push!(LOAD_PATH, "language/julia/src")
using PraxoCore

mutable struct GovState
    effects::Dict{String,Int}
    budget::Int
    children::Int
end

GovState(; budget=0) = GovState(Dict{String,Int}(), budget, 0)

struct RunConfig
    allowed::Vector{String}
    policy::AbstractPolicy
    tools::Vector{Any}
    depth::Int
    max_depth::Int
    max_children::Int
    use_budget::Bool
    use_children::Bool
    cancelled::Bool
    edit_to_blocked::Bool
end

RunConfig(allowed, policy, tools; depth=0, max_depth=-1, max_children=-1,
          use_budget=false, use_children=false, cancelled=false,
          edit_to_blocked=false) =
    RunConfig(allowed, policy, tools, depth, max_depth, max_children,
              use_budget, use_children, cancelled, edit_to_blocked)

mutable struct GovModel <: AbstractModel
    steps::Vector{Response}
end

function PraxoCore.generate(model::GovModel, request::Request)
    !isempty(model.steps) && return popfirst!(model.steps)
    return Response(PraxoCore.Models.message_assistant("done"))
end

struct PermissiveRecordPolicy <: AbstractPolicy end
struct ParentBlockedPolicy <: AbstractPolicy end
struct ComposedGovPolicy <: AbstractPolicy end

function target_of(action::Action)
    action.arguments === nothing && return ""
    return string(get(action.arguments, "target", ""))
end

function PraxoCore.authorize(::PermissiveRecordPolicy, action::Action)
    action.kind == "model.generate" && return Decision(true, "")
    (action.kind == "tool.invoke" && action.tool_name == "record") &&
        return Decision(true, "")
    return Decision(false, "child may only record")
end

function PraxoCore.authorize(::ParentBlockedPolicy, action::Action)
    action.kind == "model.generate" && return Decision(true, "")
    (action.kind == "tool.invoke" && action.tool_name == "record") ||
        return Decision(false, "parent tool is not allowed")
    target_of(action) == "blocked" && return Decision(false, "blocked target")
    return Decision(true, "")
end

function PraxoCore.authorize(::ComposedGovPolicy, action::Action)
    parent = PraxoCore.authorize(ParentBlockedPolicy(), action)
    parent.allowed || return parent
    return PraxoCore.authorize(PermissiveRecordPolicy(), action)
end

function denied_task(status::String, code::String)
    return SubagentTask("subagent", "governance-parent", "governance-child",
                        "isolated", status, "", code, "", "")
end

function make_tools(state::GovState)
    record = FuncTool("record", "record", args -> begin
        target = string(get(args, "target", ""))
        state.effects[target] = get(state.effects, target, 0) + 1
        return "ok"
    end)
    write = FuncTool("write", "write", args -> begin
        target = string(get(args, "target", ""))
        state.effects[target] = get(state.effects, target, 0) + 1
        return "ok"
    end)
    return Any[record, write]
end

function model_for(tool::String, target::String)
    return GovModel(Response[
        Response(PraxoCore.Models.message_assistant("", [
            ToolCall("call-1", tool, Dict{String,Any}("target" => target)),
        ])),
    ])
end

function run_child(state::GovState, model::AbstractModel, config::RunConfig)
    config.cancelled && return denied_task("cancelled", "CANCELLED")
    (config.max_depth >= 0 && config.depth > config.max_depth) &&
        return denied_task("denied", "DEPTH_LIMIT")
    (config.max_children >= 0 && state.children >= config.max_children) &&
        return denied_task("denied", "CHILD_LIMIT")
    (config.use_budget && state.budget <= 0) &&
        return denied_task("denied", "BUDGET_EXHAUSTED")
    if config.use_children
        state.children += 1
    end

    registry = ToolRegistry()
    for tool in config.tools
        PraxoCore.AgentRuntime.register!(registry, tool)
    end
    options = AgentOptions(model; require_policy=true, require_tool_scope=true)
    options.tools = registry
    options.allowed_tools = config.allowed
    options.policy = config.policy
    options.max_steps = 3
    if config.edit_to_blocked
        options.interrupt_on = Set(["record"])
        options.on_interrupt_decision = interrupt ->
            InterruptDecision(INTERRUPT_EDIT; arguments=Dict{String,Any}(
                "target" => "blocked",
            ))
    end
    task = subagent_run(request -> begin
        result = run_agent(Agent(options), Session("governance-child"),
                           "run child")
        return SubagentResult("child", "child", result.output)
    end, subagent_request("governance-parent", "governance-child", "run child"))
    if config.use_budget && task.status == "completed"
        state.budget -= 1
    end
    return task
end

function main()
    scope_state = GovState()
    scope = run_child(scope_state, model_for("write", "escape"),
        RunConfig(["record"], PermissiveRecordPolicy(),
                  make_tools(scope_state)))
    @assert scope.status == "failed"
    @assert get(scope_state.effects, "escape", 0) == 0

    policy_state = GovState()
    composed = run_child(policy_state, model_for("record", "blocked"),
        RunConfig(["record"], ComposedGovPolicy(),
                  make_tools(policy_state)))
    @assert composed.status == "failed"
    @assert get(policy_state.effects, "blocked", 0) == 0

    budget_state = GovState(; budget=1)
    first = run_child(budget_state, model_for("record", "sibling"),
        RunConfig(["record"], PermissiveRecordPolicy(),
                  make_tools(budget_state); use_budget=true))
    second = run_child(budget_state, model_for("record", "sibling"),
        RunConfig(["record"], PermissiveRecordPolicy(),
                  make_tools(budget_state); use_budget=true))
    @assert first.status == "completed"
    @assert second.status == "denied"
    @assert second.error == "BUDGET_EXHAUSTED"
    @assert get(budget_state.effects, "sibling", 0) == 1

    limit_state = GovState()
    first_limit = run_child(limit_state, model_for("record", "limit"),
        RunConfig(["record"], PermissiveRecordPolicy(),
                  make_tools(limit_state); max_children=1, use_children=true))
    second_limit = run_child(limit_state, model_for("record", "limit"),
        RunConfig(["record"], PermissiveRecordPolicy(),
                  make_tools(limit_state); max_children=1, use_children=true))
    deep = run_child(limit_state, model_for("record", "limit"),
        RunConfig(["record"], PermissiveRecordPolicy(),
                  make_tools(limit_state); depth=2, max_depth=1))
    @assert first_limit.status == "completed"
    @assert second_limit.error == "CHILD_LIMIT"
    @assert deep.error == "DEPTH_LIMIT"
    @assert get(limit_state.effects, "limit", 0) == 1

    cancel_state = GovState()
    cancelled = run_child(cancel_state, model_for("record", "cancel"),
        RunConfig(["record"], PermissiveRecordPolicy(),
                  make_tools(cancel_state); cancelled=true))
    @assert cancelled.status == "cancelled"
    @assert get(cancel_state.effects, "cancel", 0) == 0

    edit_state = GovState()
    edited = run_child(edit_state, model_for("record", "edit-me"),
        RunConfig(["record"], ParentBlockedPolicy(),
                  make_tools(edit_state); edit_to_blocked=true))
    @assert edited.status == "failed"
    @assert get(edit_state.effects, "edit-me", 0) == 0
    @assert get(edit_state.effects, "blocked", 0) == 0

    println("Julia advanced delegation governance: 6/6 passed")
end

main()
