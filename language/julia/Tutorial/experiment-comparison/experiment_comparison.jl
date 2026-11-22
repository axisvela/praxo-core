push!(LOAD_PATH, "language/julia/src")
using PraxoCore

const BASELINE = [0.72, 0.75, 0.74, 0.73, 0.76]
const CANDIDATE = [0.78, 0.79, 0.77, 0.80, 0.78]

struct ExperimentModel <: AbstractModel
    dataset::String
end

function PraxoCore.generate(model::ExperimentModel, request::Request)
    tool_messages = filter(message -> message.role == Roles.TOOL, request.messages)
    if !isempty(tool_messages)
        summary = PraxoCore.Json.parse_json(tool_messages[end].content)
        report = Dict("experiment" => summary, "mutating_actions" => Any[])
        return Response(PraxoCore.Models.message_assistant(PraxoCore.Json.stringify(report)))
    end
    call = ToolCall("experiment-1", "compare_experiments", Dict("name" => model.dataset))
    return Response(PraxoCore.Models.message_assistant("", [call]))
end

struct ExperimentPolicy <: AbstractPolicy end

function PraxoCore.authorize(::ExperimentPolicy, action::Action)
    if action.kind == "model.generate"
        return Decision(true, "deterministic model")
    elseif action.kind == "tool.invoke"
        name = action.arguments === nothing ? nothing : get(action.arguments, "name", nothing)
        return Decision(
            action.tool_name == "compare_experiments" && name == "fixed",
            "only the fixed experiment dataset is readable",
        )
    end
    return Decision(false, "unsupported action")
end

function compare_tool(calls::Ref{Int}, simulate_failure::Bool)
    return FuncTool("compare_experiments", "Compare fixed baseline and candidate results; no writes.", args -> begin
        calls[] += 1
        get(args, "name", nothing) == "fixed" || error("unknown experiment fixture")
        simulate_failure && error("simulated experiment dependency unavailable")
        baseline_mean = sum(BASELINE) / length(BASELINE)
        candidate_mean = sum(CANDIDATE) / length(CANDIDATE)
        Dict(
            "source" => "fixture",
            "samples" => length(BASELINE),
            "baseline_mean" => baseline_mean,
            "candidate_mean" => candidate_mean,
            "delta" => candidate_mean - baseline_mean,
            "winner" => candidate_mean > baseline_mean ? "candidate" : "baseline",
        )
    end)
end

function run_comparison(dataset::String; simulate_failure::Bool=false)
    calls = Ref(0)
    registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(registry, compare_tool(calls, simulate_failure))
    options = AgentOptions(ExperimentModel(dataset))
    options.tools = registry
    options.allowed_tools = ["compare_experiments"]
    options.policy = ExperimentPolicy()
    options.max_steps = 3
    options.require_policy = true
    options.require_tool_scope = true
    result = nothing
    caught = nothing
    try
        result = run_agent(Agent(options), Session("experiment-comparison"),
                           "Compare the fixed experiment results and report computed evidence only.")
    catch error
        caught = error
    end
    return (result, calls[], caught)
end

function run_tests()
    result, calls, caught = run_comparison("fixed")
    caught === nothing || error("success failed: $(sprint(showerror, caught))")
    result !== nothing || error("success returned no result")
    report = PraxoCore.Json.parse_json(result.output)
    experiment = report["experiment"]
    abs(experiment["baseline_mean"] - 0.74) < 1e-9 || error("baseline mean mismatch")
    abs(experiment["candidate_mean"] - 0.784) < 1e-9 || error("candidate mean mismatch")
    abs(experiment["delta"] - 0.044) < 1e-9 || error("delta mismatch")
    experiment["winner"] == "candidate" || error("winner mismatch")
    experiment["samples"] == 5 || error("sample count mismatch")
    isempty(report["mutating_actions"]) || error("unexpected mutating action")
    calls == 1 || error("success read count mismatch")

    result, calls, caught = run_comparison("other")
    caught isa PraxoError || error("denial did not fail")
    caught.code == "AGENT_POLICY_DENIED" || error("denial was not a policy error")
    calls == 0 || error("denial performed a read")

    result, calls, caught = run_comparison("fixed"; simulate_failure=true)
    caught !== nothing || error("dependency failure did not fail")
    calls == 1 || error("dependency failure read count mismatch")

    println("Julia experiment-comparison tutorial: all checks passed")
end

if "--test" in ARGS
    run_tests()
    exit(0)
end

dataset = "fixed"
if "--dataset" in ARGS
    index = findfirst(==("--dataset"), ARGS)
    index !== nothing && index < length(ARGS) && (dataset = ARGS[index + 1])
end
simulate_failure = "--simulate-failure" in ARGS
result, calls, caught = run_comparison(dataset; simulate_failure=simulate_failure)
if caught !== nothing
    println(stderr, "experiment comparison failed: reads=$calls; ", sprint(showerror, caught))
    exit(1)
end
println(result.output)
