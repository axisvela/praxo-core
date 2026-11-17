push!(LOAD_PATH, "language/julia/src")
using PraxoCore

mutable struct ChainState
    effects::Dict{String,Int}
    otel::Vector{String}
    harmovela::Vector{String}
    child_calls::Int
end

ChainState() = ChainState(Dict{String,Int}(), String[], String[], 0)

mutable struct ChainModel <: AbstractModel
    steps::Vector{Response}
    final::String
    calls::Int
    on_call::Union{Nothing,Function}
end

ChainModel(steps, final; on_call=nothing) =
    ChainModel(steps, final, 0, on_call)

function PraxoCore.generate(model::ChainModel, request::Request)
    model.calls += 1
    model.on_call === nothing || model.on_call()
    !isempty(model.steps) && return popfirst!(model.steps)
    return Response(PraxoCore.Models.message_assistant(model.final))
end

struct ParentPolicy <: AbstractPolicy end
struct ChildPolicy <: AbstractPolicy end
struct ComposedPolicy <: AbstractPolicy end

function target_of(action::Action)
    action.arguments === nothing && return ""
    return string(get(action.arguments, "target", ""))
end

function PraxoCore.authorize(::ParentPolicy, action::Action)
    action.kind == "model.generate" && return Decision(true, "")
    action.kind == "tool.invoke" || return Decision(false, "unsupported action")
    if action.tool_name == "record"
        target_of(action) == "blocked" && return Decision(false, "blocked target")
        return Decision(true, "")
    end
    action.tool_name == "delegate" && return Decision(true, "")
    return Decision(false, "parent tool is not allowed")
end

function PraxoCore.authorize(::ChildPolicy, action::Action)
    action.kind == "model.generate" && return Decision(true, "")
    (action.kind == "tool.invoke" && action.tool_name == "record") &&
        return Decision(true, "")
    return Decision(false, "child may only record")
end

function PraxoCore.authorize(::ComposedPolicy, action::Action)
    parent = PraxoCore.authorize(ParentPolicy(), action)
    parent.allowed || return parent
    return PraxoCore.authorize(ChildPolicy(), action)
end

function record_call(id::String, target::String)
    return ToolCall(id, "record", Dict{String,Any}("target" => target))
end

function tool_response(call::ToolCall)
    return Response(PraxoCore.Models.message_assistant("", [call]))
end

function main()
    state = ChainState()
    transport = (method, params) -> begin
        if method == "initialize"
            return Dict{String,Any}(
                "protocolVersion" => "2024-11-05",
                "serverInfo" => Dict{String,Any}("name" => "fake-mcp"),
            )
        elseif method == "tools/list"
            return Dict{String,Any}(
                "tools" => Any[Dict{String,Any}(
                    "name" => "record",
                    "description" => "Record a target",
                    "inputSchema" => Dict{String,Any}(
                        "type" => "object",
                        "properties" => Dict{String,Any}(
                            "target" => Dict{String,Any}("type" => "string"),
                        ),
                        "required" => Any["target"],
                    ),
                )],
            )
        elseif method == "tools/call"
            args = get(params, "arguments", Dict{String,Any}())
            target = string(get(args, "target", ""))
            state.effects[target] = get(state.effects, target, 0) + 1
            return Dict{String,Any}(
                "content" => Any[Dict{String,Any}(
                    "type" => "text",
                    "text" => "recorded:" * target,
                )],
            )
        end
        return Dict{String,Any}()
    end
    client = mcp_client(transport)
    tools = mcp_list_tools(client)
    @assert length(tools) == 1

    record = FuncTool("record", "Record a target through the MCP client",
        args -> mcp_call_tool(client, "record", args))

    otel = otel_sink("http://otel.local/v1/traces";
        transport = (endpoint, body, headers) -> begin
            payload = Json.parse_json(body)
            for resource in Json.getarray(payload, "resourceSpans")
                for scope in Json.getarray(resource, "scopeSpans")
                    for span in Json.getarray(scope, "spans")
                        push!(state.otel, string(Json.getvalue(span, "name", "")))
                    end
                end
            end
            return (200, "")
        end)
    harmovela = harmovela_sink("http://harmovela.local";
        transport = (path, body, headers) -> begin
            payload = Json.parse_json(body)
            push!(state.harmovela, string(Json.getvalue(payload, "type", "")))
            return (202, "")
        end)
    events = MultiSink(AbstractSink[otel, harmovela])

    delegate = FuncTool("delegate",
        "Run a governed child agent with the narrowed record scope",
        args -> begin
            child_model = ChainModel(
                Response[tool_response(record_call("child-record", "child"))],
                "DONE";
                on_call = () -> (state.child_calls += 1),
            )
            registry = ToolRegistry()
            PraxoCore.AgentRuntime.register!(registry, record)
            options = AgentOptions(child_model;
                require_policy = true, require_tool_scope = true)
            options.tools = registry
            options.events = events
            options.policy = ComposedPolicy()
            options.allowed_tools = ["record"]
            options.max_steps = 3
            result = run_agent(Agent(options), Session("chain-child"),
                               "record child")
            return Dict{String,Any}(
                "output" => result.output,
                "effects" => get(state.effects, "child", 0),
            )
        end)

    parent_model = ChainModel(Response[
        tool_response(record_call("parent-record", "parent")),
        tool_response(ToolCall("parent-delegate", "delegate",
                               Dict{String,Any}("task" => "record child"))),
    ], "DONE")
    registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(registry, record)
    PraxoCore.AgentRuntime.register!(registry, delegate)
    options = AgentOptions(parent_model;
        require_policy = true, require_tool_scope = true)
    options.tools = registry
    options.events = events
    options.policy = ParentPolicy()
    options.allowed_tools = ["record", "delegate"]
    options.max_steps = 4
    parent = run_agent(Agent(options), Session("chain-parent"),
                       "record parent, then delegate")

    denied_model = ChainModel(Response[
        tool_response(record_call("denied-record", "edit-me")),
    ], "DONE")
    denied_registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(denied_registry, record)
    denied_options = AgentOptions(denied_model;
        require_policy = true, require_tool_scope = true)
    denied_options.tools = denied_registry
    denied_options.events = events
    denied_options.policy = ParentPolicy()
    denied_options.allowed_tools = ["record"]
    denied_options.max_steps = 2
    denied_options.interrupt_on = Set(["record"])
    denied_options.on_interrupt_decision = interrupt ->
        InterruptDecision(INTERRUPT_EDIT; arguments = Dict{String,Any}(
            "target" => "blocked",
        ))
    denied_error = ""
    try
        run_agent(Agent(denied_options), Session("chain-denied"),
                  "attempt a denied edit")
    catch error
        denied_error = error isa PraxoError ? error.code : string(error)
    end

    mcp_close!(client)
    println("output: ", parent.output)
    println("effects: parent=", get(state.effects, "parent", 0),
            " child=", get(state.effects, "child", 0))
    println("child calls: ", state.child_calls)
    println("otel spans: ", length(state.otel))
    println("harmovela events: ", length(state.harmovela))
    println("denied effects: ", get(state.effects, "blocked", 0))
    @assert parent.output == "DONE"
    @assert get(state.effects, "parent", 0) == 1
    @assert get(state.effects, "child", 0) == 1
    @assert state.child_calls == 2
    @assert length(state.otel) >= 3
    @assert length(state.harmovela) >= 3
    @assert get(state.effects, "blocked", 0) == 0
    @assert !isempty(denied_error)
end

main()
