push!(LOAD_PATH, "language/julia/src")
using PraxoCore

const SCOPE_ID = "material-100"

struct FixtureModel <: AbstractModel
    scope::String
end

function PraxoCore.generate(model::FixtureModel, request::Request)
    results = filter(message -> message.role == Roles.TOOL, request.messages)
    if isempty(results)
        return Response(PraxoCore.Models.message_assistant("", [
            ToolCall("tool-1", "evaluate_candidates", Dict("material_id" => model.scope, "action" => "draft_simulation")),
        ]))
    end
    evidence = PraxoCore.Json.parse_json(results[1].content)
    if haskey(evidence, "error")
        return Response(PraxoCore.Models.message_assistant(evidence["error"]))
    end
    report = Dict(
        "stage" => "simulation_drafted",
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
        scope = get(args, "material_id", nothing)
        scope == SCOPE_ID || return Decision(false, "only material-100 is in scope")
        if action.tool_name == "evaluate_candidates" && get(args, "action", nothing) == "draft_simulation"
            return Decision(true, "material-100 review-only draft")
        end
    end
    return Decision(false, "unsupported action")
end

function fixture_tool(calls::Ref{Int}, simulate_failure::Bool)
    FuncTool("evaluate_candidates", "Evaluate fixed candidate properties and draft the next simulation.", args -> begin
        calls[] += 1
        get(args, "material_id", nothing) == SCOPE_ID || error("scope outside fixture")
        simulate_failure && error("MATERIAL_DATA_UNAVAILABLE")
        Dict(
            "id" => SCOPE_ID,
            "candidates" => 2, "selected" => 1, "validated_material" => false,
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
    options.allowed_tools = ["evaluate_candidates"]
    options.policy = FixturePolicy()
    options.max_steps = 3
    options.require_policy = true
    options.require_tool_scope = true
    result = nothing
    caught = nothing
    try
        result = run_agent(Agent(options), Session("materials-design"), "Evaluate fixed candidate properties and draft the next simulation.")
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
    println("success: material-100 selected=1 status=draft_only validated=false reads=1")

    _, denied_reads, denied = run_case("material-200")
    denied isa PraxoError || error("denial did not fail")
    denied.code == "AGENT_POLICY_DENIED" || error("denial code")
    denied_reads == 0 || error("denial reads")
    println("deny: AGENT_POLICY_DENIED reads=0")

    _, failed_reads, failed = run_case(SCOPE_ID; simulate_failure=true)
    failed isa PraxoError || error("failure did not fail")
    occursin("MATERIAL_DATA_UNAVAILABLE", sprint(showerror, failed)) || error("failure code")
    failed_reads == 1 || error("failure reads")
    println("failure: MATERIAL_DATA_UNAVAILABLE reads=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    if "--test" in ARGS
        run_tests()
    else
        scope = SCOPE_ID
        index = findfirst(==("--material"), ARGS)
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
