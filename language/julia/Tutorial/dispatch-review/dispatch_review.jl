push!(LOAD_PATH, "language/julia/src")
using PraxoCore

const DEMAND = 100
const SHORT_DEMAND = 130
const CAP_A = 60
const CAP_B = 60
const COST_A = 30
const COST_B = 50
const UNMET_COST = 1000

function solve(demand::Int)
    best = nothing
    for a in 0:min(CAP_A, demand)
        b_requested = demand - a
        b = min(CAP_B, b_requested)
        unmet = demand - a - b
        cost = a * COST_A + b * COST_B + unmet * UNMET_COST
        candidate = Dict(
            "source_a" => a,
            "source_b" => b,
            "unmet" => unmet,
            "cost" => cost,
            "feasible" => unmet == 0,
        )
        if best === nothing || cost < best["cost"]
            best = candidate
        end
    end
    return best
end

struct DispatchModel <: AbstractModel
    scenario::String
end

function PraxoCore.generate(model::DispatchModel, request::Request)
    results = filter(message -> message.role == Roles.TOOL, request.messages)
    if isempty(results)
        return Response(PraxoCore.Models.message_assistant("", [
            ToolCall("dispatch-1", "solve_dispatch", Dict("scenario" => model.scenario)),
        ]))
    end
    evidence = PraxoCore.Json.parse_json(results[1].content)
    if haskey(evidence, "error")
        return Response(PraxoCore.Models.message_assistant(evidence["error"]))
    end
    if length(results) == 1
        action = evidence["feasible"] ? "review_plan" : "review_shortfall"
        return Response(PraxoCore.Models.message_assistant("", [
            ToolCall("review-1", "draft_review",
                     Dict("scenario" => model.scenario, "action" => action)),
        ]))
    end
    review = PraxoCore.Json.parse_json(results[end].content)
    report = Dict(
        "stage" => "dispatch_reviewed",
        "dispatch" => evidence,
        "review" => review,
        "grid_commands" => 0,
    )
    return Response(PraxoCore.Models.message_assistant(PraxoCore.Json.stringify(report)))
end

struct DispatchPolicy <: AbstractPolicy end

function PraxoCore.authorize(::DispatchPolicy, action::Action)
    if action.kind == "model.generate"
        return Decision(true, "deterministic dispatch")
    elseif action.kind == "tool.invoke"
        args = action.arguments === nothing ? Dict() : action.arguments
        scope = get(args, "scenario", nothing)
        scope == "scenario-100" || return Decision(false, "scenario outside scope")
        if action.tool_name == "solve_dispatch"
            return Decision(true, "bounded dispatch calculation")
        elseif action.tool_name == "draft_review"
            choice = get(args, "action", nothing)
            return Decision(choice in ("review_plan", "review_shortfall"), "review-only action")
        end
    end
    return Decision(false, "unsupported action")
end

function solve_tool(calls::Ref{Int}, demand::Int, simulate_failure::Bool)
    FuncTool("solve_dispatch", "Enumerate a bounded two-source dispatch; no grid control.", args -> begin
        calls[] += 1
        get(args, "scenario", nothing) == "scenario-100" || error("scenario outside fixture")
        simulate_failure && error("DISPATCH_DATA_UNAVAILABLE")
        solution = solve(demand)
        merge(solution, Dict("demand" => demand, "capacity_a" => CAP_A,
                             "capacity_b" => CAP_B, "source" => "dispatch_fixture"))
    end)
end

function review_tool(calls::Ref{Int})
    FuncTool("draft_review", "Draft a review-only dispatch or shortfall action; no commands.", args -> begin
        calls[] += 1
        Dict(
            "review_id" => "dispatch-100",
            "scenario" => get(args, "scenario", ""),
            "action" => get(args, "action", ""),
            "status" => "draft_only",
            "review_required" => true,
            "grid_commands" => 0,
        )
    end)
end

function run_dispatch(demand::Int; scenario::String="scenario-100", simulate_failure::Bool=false)
    reads = Ref(0)
    drafts = Ref(0)
    registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(registry, solve_tool(reads, demand, simulate_failure))
    PraxoCore.AgentRuntime.register!(registry, review_tool(drafts))
    options = AgentOptions(DispatchModel(scenario))
    options.tools = registry
    options.allowed_tools = ["solve_dispatch", "draft_review"]
    options.policy = DispatchPolicy()
    options.max_steps = 4
    options.require_policy = true
    options.require_tool_scope = true
    result = nothing
    caught = nothing
    try
        result = run_agent(Agent(options), Session("dispatch-review"),
                           "Solve the bounded dispatch and draft the appropriate review.")
    catch error
        caught = error
    end
    return (result, reads[], drafts[], caught)
end

function run_tests()
    result, reads, drafts, caught = run_dispatch(DEMAND)
    caught === nothing || error("success failed: $(sprint(showerror, caught))")
    reads == 1 && drafts == 1 || error("success counts")
    report = PraxoCore.Json.parse_json(result.output)
    dispatch = report["dispatch"]
    dispatch["source_a"] == 60 || error("source A mismatch")
    dispatch["source_b"] == 40 || error("source B mismatch")
    dispatch["cost"] == 3800 || error("cost mismatch")
    dispatch["feasible"] == true || error("feasibility mismatch")
    report["review"]["action"] == "review_plan" || error("plan branch")
    report["grid_commands"] == 0 || error("grid commands")

    short, short_reads, short_drafts, short_error = run_dispatch(SHORT_DEMAND)
    short_error === nothing || error("shortfall path failed")
    short_reads == 1 && short_drafts == 1 || error("shortfall counts")
    short_report = PraxoCore.Json.parse_json(short.output)
    short_report["dispatch"]["unmet"] == 10 || error("shortfall unmet mismatch")
    short_report["dispatch"]["feasible"] == false || error("shortfall feasibility")
    short_report["review"]["action"] == "review_shortfall" || error("shortfall branch")

    _, denied_reads, denied_drafts, denied = run_dispatch(DEMAND; scenario="scenario-200")
    denied isa PraxoError || error("denial did not fail")
    denied.code == "AGENT_POLICY_DENIED" || error("denial code")
    denied_reads == 0 && denied_drafts == 0 || error("denial counts")

    failed_result, failed_reads, failed_drafts, failed = run_dispatch(
        DEMAND; simulate_failure=true)
    failed !== nothing || error("failure path unexpectedly succeeded")
    failed_reads == 1 && failed_drafts == 0 || error("failure counts")
    occursin("DISPATCH_DATA_UNAVAILABLE", sprint(showerror, failed)) || error("failure code")

    println("Julia dispatch-review tutorial: optimization, branches, denial and failure passed")
end

function main(args)
    if "--test" in args
        run_tests()
        return
    end
    demand = "--shortfall" in args ? SHORT_DEMAND : DEMAND
    failure = "--simulate-failure" in args
    result, reads, drafts, caught = run_dispatch(demand; simulate_failure=failure)
    if caught !== nothing
        println(stderr, "dispatch review failed: reads=$(reads) drafts=$(drafts); $(sprint(showerror, caught))")
        exit(1)
    end
    println(result.output)
end

main(ARGS)
