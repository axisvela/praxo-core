push!(LOAD_PATH, "language/julia/src")
using PraxoCore

const SCOPE_ID = "mesh-100"

struct FixtureModel <: AbstractModel
    scope::String
end

function PraxoCore.generate(model::FixtureModel, request::Request)
    results = filter(message -> message.role == Roles.TOOL, request.messages)
    if isempty(results)
        return Response(PraxoCore.Models.message_assistant("", [
            ToolCall("tool-1", "review_mesh", Dict("mesh_id" => model.scope, "action" => "draft_assessment")),
        ]))
    end
    evidence = PraxoCore.Json.parse_json(results[1].content)
    if haskey(evidence, "error")
        return Response(PraxoCore.Models.message_assistant(evidence["error"]))
    end
    report = Dict(
        "stage" => "mesh_review_drafted",
        "result" => evidence,
        "writes" => 0,
    )
    return Response(PraxoCore.Models.message_assistant(PraxoCore.Json.stringify(report)))
end

struct FixturePolicy <: AbstractPolicy end

function PraxoCore.authorize(::FixturePolicy, action::Action)
    if action.kind == "model.generate"
        return Decision(true, "deterministic tutorial review")
    elseif action.kind == "tool.invoke"
        args = action.arguments === nothing ? Dict() : action.arguments
        scope = get(args, "mesh_id", nothing)
        scope == SCOPE_ID || return Decision(false, "only mesh-100 is in scope")
        if action.tool_name == "review_mesh" && get(args, "action", nothing) == "draft_assessment"
            return Decision(true, "mesh-100 review-only draft")
        end
    end
    return Decision(false, "unsupported action")
end

function fixture_tool(calls::Ref{Int}, simulate_failure::Bool)
    FuncTool("review_mesh", "Compare fixed mesh descriptors against stated constraints.", args -> begin
        calls[] += 1
        get(args, "mesh_id", nothing) == SCOPE_ID || error("scope outside fixture")
        simulate_failure && error("MESH_DATA_UNAVAILABLE")
        Dict(
            "id" => SCOPE_ID,
            "nodes" => 3, "overlaps" => 0, "certified" => false,
            "status" => "draft_only",
            "review_required" => true,
            "writes" => 0,
            "source" => "fixture",
        )
    end)
end

function run_case(scope::String= SCOPE_ID; simulate_failure::Bool=false)
    calls = Ref(0)
    registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(registry, fixture_tool(calls, simulate_failure))
    options = AgentOptions(FixtureModel(scope))
    options.tools = registry
    options.allowed_tools = ["review_mesh"]
    options.policy = FixturePolicy()
    options.max_steps = 3
    options.require_policy = true
    options.require_tool_scope = true
    result = nothing
    caught = nothing
    try
        result = run_agent(Agent(options), Session("mesh-review"), "Compare fixed mesh descriptors against stated constraints.")
    catch error
        caught = error
    end
    return (result, calls[], caught)
end

function run_tests()
    result, reads, caught = run_case()
    caught === nothing || error("success failed: $(sprint(showerror, caught))")
    reads == 1 || error("read count")
    report = PraxoCore.Json.parse_json(result.output)
    report["result"]["status"] == "draft_only" || error("status")
    report["result"]["writes"] == 0 || error("writes")
    report["writes"] == 0 || error("report writes")
    println("success: mesh-100 overlaps=0 status=draft_only certified=false reads=1")

    _, denied_reads, denied = run_case("mesh-200")
    denied isa PraxoError || error("denial did not fail")
    denied.code == "AGENT_POLICY_DENIED" || error("denial code")
    denied_reads == 0 || error("denial reads")
    println("deny: AGENT_POLICY_DENIED reads=0")

    _, failed_reads, failed = run_case(SCOPE_ID; simulate_failure=true)
    failed isa PraxoError || error("failure did not fail")
    occursin("MESH_DATA_UNAVAILABLE", sprint(showerror, failed)) || error("failure code")
    failed_reads == 1 || error("failure reads")
    println("failure: MESH_DATA_UNAVAILABLE reads=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    if "--test" in ARGS
        run_tests()
    else
        scope = SCOPE_ID
        index = findfirst(==("--mesh"), ARGS)
        if index !== nothing && index < length(ARGS)
            scope = ARGS[index + 1]
        end
        result, reads, caught = run_case(scope; simulate_failure="--simulate-failure" in ARGS)
        if caught !== nothing
            println(stderr, "error: ", caught.code, " reads=", reads)
            exit(caught.code == "AGENT_POLICY_DENIED" ? 2 : 1)
        end
        println(result.output)
        println("reads=", reads)
    end
end
