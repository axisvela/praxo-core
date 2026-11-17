push!(LOAD_PATH, "language/julia/src")
using PraxoCore

mutable struct DemoState
    effects::Dict{String,Int}
    child_calls::Int
end

DemoState() = DemoState(Dict{String,Int}(), 0)

mutable struct DemoModel <: AbstractModel
    steps::Vector{Response}
    final::String
    on_call::Union{Nothing,Function}
end

DemoModel(steps, final; on_call=nothing) = DemoModel(steps, final, on_call)

function PraxoCore.generate(model::DemoModel, request::Request)
    model.on_call === nothing || model.on_call()
    !isempty(model.steps) && return popfirst!(model.steps)
    return Response(PraxoCore.Models.message_assistant(model.final))
end

struct DemoParentPolicy <: AbstractPolicy end
struct DemoChildPolicy <: AbstractPolicy end

function PraxoCore.authorize(::DemoParentPolicy, action::Action)
    action.kind == "model.generate" && return Decision(true, "")
    (action.kind == "tool.invoke" && action.tool_name == "delegate") &&
        return Decision(true, "")
    return Decision(false, "parent may only delegate")
end

function PraxoCore.authorize(::DemoChildPolicy, action::Action)
    action.kind == "model.generate" && return Decision(true, "")
    (action.kind == "tool.invoke" && action.tool_name == "record") &&
        return Decision(true, "")
    return Decision(false, "child may only record")
end

function record_call(id::String, target::String)
    return ToolCall(id, "record", Dict{String,Any}("target" => target))
end

function main()
    state = DemoState()
    record = FuncTool("record", "Record a target in an in-memory counter",
        args -> begin
            target = string(get(args, "target", ""))
            state.effects[target] = get(state.effects, target, 0) + 1
            return "recorded:" * target
        end)
    child_model = DemoModel(
        Response[tool_response(record_call("child-record", "child"))],
        "child done";
        on_call = () -> (state.child_calls += 1),
    )
    delegate = FuncTool("delegate",
        "Run a child agent with a narrowed record scope",
        args -> begin
            registry = ToolRegistry()
            PraxoCore.AgentRuntime.register!(registry, record)
            options = AgentOptions(child_model;
                require_policy = true, require_tool_scope = true)
            options.tools = registry
            options.policy = DemoChildPolicy()
            options.allowed_tools = ["record"]
            options.max_steps = 3
            result = run_agent(Agent(options), Session("demo-child"),
                               "record child")
            return result.output
        end)
    parent_model = DemoModel(
        Response[tool_response(ToolCall("parent-delegate", "delegate",
                                        Dict{String,Any}("task" => "record child")))],
        "parent done",
    )
    registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(registry, record)
    PraxoCore.AgentRuntime.register!(registry, delegate)
    options = AgentOptions(parent_model;
        require_policy = true, require_tool_scope = true)
    options.tools = registry
    options.policy = DemoParentPolicy()
    options.allowed_tools = ["delegate"]
    result = run_agent(Agent(options), Session("demo-parent"), "delegate")
    println("delegation: child recorded; parent scope enforced")

    direct_model = DemoModel(
        Response[tool_response(record_call("direct-record", "child"))],
        "parent done",
    )
    direct_options = AgentOptions(direct_model;
        require_policy = true, require_tool_scope = true)
    direct_options.tools = registry
    direct_options.policy = DemoParentPolicy()
    direct_options.allowed_tools = ["delegate"]
    denied = false
    try
        run_agent(Agent(direct_options), Session("demo-direct"),
                  "record directly")
    catch error
        denied = error isa PraxoError
    end
    println("deny: parent record blocked; child effect unchanged")
    @assert result.output == "parent done"
    @assert get(state.effects, "child", 0) == 1
    @assert denied
end

function tool_response(call::ToolCall)
    return Response(PraxoCore.Models.message_assistant("", [call]))
end

main()
