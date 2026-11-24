push!(LOAD_PATH, "language/julia/src")
using PraxoCore

const SCOPE_ID = "screening-100"

struct FixtureModel <: AbstractModel
    scope::String
end

function PraxoCore.generate(model::FixtureModel, request::Request)
    results = filter(message -> message.role == Roles.TOOL, request.messages)
    if isempty(results)
        return Response(PraxoCore.Models.message_assistant("", [
            ToolCall("tool-1", "rank_descriptors", Dict("screening_id" => model.scope, "action" => "draft_review")),
        ]))
    end
    evidence = PraxoCore.Json.parse_json(results[1].content)
    if haskey(evidence, "error")
        return Response(PraxoCore.Models.message_assistant(evidence["error"]))
    end
    report = Dict(
        "stage" => "screen_review_drafted",
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
        scope = get(args, "screening_id", nothing)
        scope == SCOPE_ID || return Decision(false, "only screening-100 is in scope")
        if action.tool_name == "rank_descriptors" && get(args, "action", nothing) == "draft_review"
            return Decision(true, "screening-100 review-only draft")
        end
    end
    return Decision(false, "unsupported action")
end

function fixture_tool(calls::Ref{Int}, simulate_failure::Bool)
    FuncTool("rank_descriptors", "Rank fixed synthetic descriptors and draft a review.", args -> begin
        calls[] += 1
        get(args, "screening_id", nothing) == SCOPE_ID || error("scope outside fixture")
        simulate_failure && error("DESCRIPTOR_DATA_UNAVAILABLE")
        Dict(
            "id" => SCOPE_ID,
            "candidates" => 3, "ranked" => 2, "efficacy_claim" => false,
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
    options.allowed_tools = ["rank_descriptors"]
    options.policy = FixturePolicy()
    options.max_steps = 3
    options.require_policy = true
    options.require_tool_scope = true
    result = nothing
    caught = nothing
    try
        result = run_agent(Agent(options), Session("molecule-screen"), "Rank fixed synthetic descriptors and draft a review.")
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
    println("success: screening-100 ranked=2 status=draft_only efficacy=false reads=1")

    _, denied_reads, denied = run_case("screening-200")
    denied isa PraxoError || error("denial did not fail")
    denied.code == "AGENT_POLICY_DENIED" || error("denial code")
    denied_reads == 0 || error("denial reads")
    println("deny: AGENT_POLICY_DENIED reads=0")

    _, failed_reads, failed = run_case(SCOPE_ID; simulate_failure=true)
    failed isa PraxoError || error("failure did not fail")
    occursin("DESCRIPTOR_DATA_UNAVAILABLE", sprint(showerror, failed)) || error("failure code")
    failed_reads == 1 || error("failure reads")
    println("failure: DESCRIPTOR_DATA_UNAVAILABLE reads=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    if "--test" in ARGS
        run_tests()
    else
        scope = SCOPE_ID
        index = findfirst(==("--screening"), ARGS)
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
