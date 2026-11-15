push!(LOAD_PATH, "language/julia/src")
using PraxoCore

struct FixtureModel <: AbstractModel
    target::String
end

function PraxoCore.generate(model::FixtureModel, request::Request)
    if !isempty(request.messages) && request.messages[end].role == Roles.TOOL
        return Response(PraxoCore.Models.message_assistant("recorded"))
    end
    call = ToolCall("record-1", "record", Dict{String,Any}("target" => model.target))
    return Response(PraxoCore.Models.message_assistant("", [call]))
end

struct TargetPolicy <: AbstractPolicy end

function PraxoCore.authorize(::TargetPolicy, action::Action)
    if action.kind == "model.generate"
        return Decision(true, "model generation")
    elseif action.kind == "tool.invoke"
        target = action.arguments === nothing ? nothing : get(action.arguments, "target", nothing)
        if action.tool_name == "record" && target == "public"
            return Decision(true, "public target")
        end
        return Decision(false, "only the public target is permitted")
    end
    return Decision(false, "unsupported action")
end

function run_case(target::String)
    effects = Ref(0)
    tool = FuncTool("record", "Record a target in an in-memory counter.", args -> begin
        effects[] += 1
        return "recorded"
    end)
    registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(registry, tool)
    options = AgentOptions(FixtureModel(target))
    options.tools = registry
    options.allowed_tools = ["record"]
    options.policy = TargetPolicy()
    options.max_steps = 3
    options.require_policy = true
    options.require_tool_scope = true
    result = nothing
    caught = nothing
    try
        result = run_agent(Agent(options), Session("consumer-" * target),
                           "Record the requested target.")
    catch error
        caught = error
    end
    return (result, caught, effects[])
end

function main()
    result, caught, effects = run_case("public")
    if caught !== nothing || result === nothing || result.output != "recorded" || effects != 1
        println(stderr, "allow verification failed: output=",
                result === nothing ? "<none>" : repr(result.output),
                " effects=", effects, " error=",
                caught === nothing ? "<none>" : sprint(showerror, caught))
        exit(1)
    end
    println("allow: recorded; effects=1")

    result, caught, effects = run_case("private")
    if !(caught isa PraxoError) || caught.code != "AGENT_POLICY_DENIED" || effects != 0
        println(stderr, "deny verification failed: effects=", effects, " error=",
                caught === nothing ? "<none>" : sprint(showerror, caught))
        exit(1)
    end
    println("deny: policy rejected; effects=0")
end

main()
