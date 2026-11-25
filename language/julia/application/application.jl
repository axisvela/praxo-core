push!(LOAD_PATH, "language/julia/src")
using PraxoCore
using LinearAlgebra

const TENANT = "lab-ops"
const DATASET = "yield-fixture"
const X = collect(0.0:0.1:1.0)
const Y = [
    0.550, 0.648, 0.730, 0.798, 0.850,
    0.888, 0.910, 0.918, 0.910, 0.887, 0.850,
]

mutable struct AnalysisState
    tenant::String
    dataset::String
    loaded::Bool
    reads::Int
    fits::Int
    writes::Int
    simulate_failure::Bool
    last_fit::Union{Nothing,Dict{String,Any}}
end

AnalysisState(tenant::String, dataset::String, simulate_failure::Bool) =
    AnalysisState(tenant, dataset, false, 0, 0, 0, simulate_failure, nothing)

mutable struct TraceSink <: AbstractSink
    types::Vector{String}
    tools::Vector{String}
end

TraceSink() = TraceSink(String[], String[])

function PraxoCore.emit(sink::TraceSink, event::Event)
    push!(sink.types, event.type)
    if event.type == "tool.call" && event.data !== nothing
        push!(sink.tools, String(get(event.data, "name", "")))
    end
end

struct AnalysisModel <: AbstractModel
    mode::String
end

function PraxoCore.generate(model::AnalysisModel, request::Request)
    tools = filter(message -> message.role == Roles.TOOL, request.messages)
    if model.mode == "direct"
        call = ToolCall("publish-1", "publish_experiment",
                        Dict("dataset" => DATASET))
        return Response(PraxoCore.Models.message_assistant("", [call]))
    elseif model.mode == "other"
        call = ToolCall("load-1", "load_observations",
                        Dict("dataset" => "other-fixture"))
        return Response(PraxoCore.Models.message_assistant("", [call]))
    elseif model.mode == "weak"
        call = ToolCall("fit-1", "fit_response_surface",
                        Dict("dataset" => DATASET))
        return Response(PraxoCore.Models.message_assistant("", [call]))
    elseif isempty(tools)
        call = ToolCall("load-1", "load_observations",
                        Dict("dataset" => DATASET))
        return Response(PraxoCore.Models.message_assistant("", [call]))
    elseif length(tools) == 1
        call = ToolCall("fit-1", "fit_response_surface",
                        Dict("dataset" => DATASET))
        return Response(PraxoCore.Models.message_assistant("", [call]))
    end
    text = "The quadratic response peaks inside the tested range; " *
           "the computed optimum is review-only evidence, not a published experiment."
    return Response(PraxoCore.Models.message_assistant(text))
end

struct AnalysisPolicy <: AbstractPolicy
    tenant::String
end

function PraxoCore.authorize(policy::AnalysisPolicy, action::Action)
    policy.tenant == TENANT ||
        return Decision(false, "tenant mismatch")
    action.kind == "model.generate" &&
        return Decision(true, "scientific analysis generation")
    action.kind == "tool.invoke" || return Decision(false, "unsupported action")
    dataset = action.arguments === nothing ? nothing :
        get(action.arguments, "dataset", nothing)
    if action.tool_name == "load_observations"
        return Decision(dataset == DATASET, "load the fixed yield fixture")
    elseif action.tool_name == "fit_response_surface"
        return Decision(dataset == DATASET, "fit the fixed yield fixture")
    end
    return Decision(false, "publishing is not part of the agent path")
end

function load_tool(state::AnalysisState)
    return FuncTool("load_observations",
                    "Load the fixed yield observations; read-only.", args -> begin
        dataset = get(args, "dataset", "")
        dataset == DATASET || error("unknown dataset: $(dataset)")
        state.loaded = true
        state.reads += 1
        Dict{String,Any}(
            "source" => DATASET,
            "samples" => length(X),
            "x" => X,
            "y" => Y,
            "x_min" => minimum(X),
            "x_max" => maximum(X),
        )
    end)
end

function fit_tool(state::AnalysisState)
    return FuncTool("fit_response_surface",
                    "Fit a quadratic response surface and find a bounded optimum.",
                    args -> begin
        dataset = get(args, "dataset", "")
        dataset == DATASET || error("unknown dataset: $(dataset)")
        state.loaded || error("observations must be loaded before fitting")
        state.fits += 1
        state.simulate_failure && error("simulated numerical dependency unavailable")
        design = hcat(ones(length(X)), X, X .^ 2)
        coefficients = design \ Y
        predicted = design * coefficients
        residual = sum((Y .- predicted) .^ 2)
        total = sum((Y .- sum(Y) / length(Y)) .^ 2)
        r_squared = 1.0 - residual / total
        c, b, a = coefficients[1], coefficients[2], coefficients[3]
        vertex = a < 0 ? -b / (2a) : nothing
        lower, upper = minimum(X), maximum(X)
        optimum = if vertex === nothing
            predicted_at(lower, c, b, a) >= predicted_at(upper, c, b, a) ? lower : upper
        else
            clamp(vertex, lower, upper)
        end
        result = Dict{String,Any}(
            "dataset" => DATASET,
            "samples" => length(X),
            "degree" => 2,
            "coefficients" => [c, b, a],
            "r_squared" => r_squared,
            "bounds" => [lower, upper],
            "optimum_x" => optimum,
            "predicted_yield" => predicted_at(optimum, c, b, a),
            "baseline_mean" => sum(Y) / length(Y),
            "method" => "ordinary_least_squares",
        )
        state.last_fit = result
        result
    end)
end

predicted_at(x, c, b, a) = c + b * x + a * x^2

function publish_tool(state::AnalysisState)
    return FuncTool("publish_experiment",
                    "Would publish an experiment record; always denied.", args -> begin
        state.writes += 1
        Dict{String,Any}("published" => true)
    end)
end

function tool_schemas(handler)
    return function (request)
        request.tools = [
            ToolSpec("load_observations",
                     "Load the fixed yield observations.",
                     Dict{String,Any}(
                         "type" => "object",
                         "properties" => Dict{String,Any}(
                             "dataset" => Dict{String,Any}(
                                 "type" => "string",
                                 "enum" => [DATASET],
                             ),
                         ),
                         "required" => ["dataset"],
                     ),
                     "read"),
            ToolSpec("fit_response_surface",
                     "Fit a quadratic response surface and find a bounded optimum.",
                     Dict{String,Any}(
                         "type" => "object",
                         "properties" => Dict{String,Any}(
                             "dataset" => Dict{String,Any}(
                                 "type" => "string",
                                 "enum" => [DATASET],
                             ),
                         ),
                         "required" => ["dataset"],
                     ),
                     "read"),
            ToolSpec("publish_experiment",
                     "Publish an experiment record. Denied by policy.",
                     Dict{String,Any}(
                         "type" => "object",
                         "properties" => Dict{String,Any}(
                             "dataset" => Dict{String,Any}("type" => "string"),
                         ),
                     ),
                     "write"),
        ]
        return handler(request)
    end
end

function run_analysis(; live::Bool=false, mode::String="normal",
                      tenant::String=TENANT, simulate_failure::Bool=false)
    state = AnalysisState(tenant, DATASET, simulate_failure)
    sink = TraceSink()
    registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(registry, load_tool(state))
    PraxoCore.AgentRuntime.register!(registry, fit_tool(state))
    PraxoCore.AgentRuntime.register!(registry, publish_tool(state))
    model = live ? live_model() : AnalysisModel(mode)
    options = AgentOptions(model)
    options.tools = registry
    options.allowed_tools = ["load_observations", "fit_response_surface",
                             "publish_experiment"]
    options.policy = AnalysisPolicy(tenant)
    options.require_policy = true
    options.require_tool_scope = true
    options.events = sink
    options.max_steps = 6
    options.system_prompt =
        "You are a scientific analysis agent. Use load_observations and " *
        "fit_response_surface for the fixed yield fixture. The tenant is $(TENANT). " *
        "Never publish an experiment or invent computed values."
    if live
        options.model_middleware = Function[tool_schemas]
    end
    result = nothing
    caught = nothing
    try
        result = run_agent(Agent(options), Session("scientific-copilot"),
                           "Analyze the yield fixture, fit the response surface, " *
                           "and report the bounded optimum with evidence.")
    catch error
        caught = error
    end
    report = nothing
    if caught === nothing
        state.last_fit === nothing &&
            error("agent completed without a fitted response surface")
        state.writes == 0 || error("unexpected experiment publication")
        output = result === nothing ? "" : strip(result.output)
        interpretation = isempty(output) ?
            "The computed response surface is review-only evidence." :
            length(output) > 1600 ? first(output, 1597) * "..." : output
        report = Dict{String,Any}(
            "dataset" => DATASET,
            "model" => live ? "live" : "deterministic",
            "fit" => state.last_fit,
            "interpretation" => interpretation,
            "agent" => Dict{String,Any}(
                "reads" => state.reads,
                "fits" => state.fits,
                "writes" => state.writes,
                "tools" => sink.tools,
                "events" => sink.types,
            ),
            "mutating_actions" => Any[],
        )
    end
    return (report=report, result=result, error=caught, state=state, sink=sink)
end

function curl_post(url::String, body::Dict{String,Any},
                   api_key::Union{Nothing,String})
    input = tempname()
    output = tempname()
    try
        open(input, "w") do io
            write(io, PraxoCore.Json.stringify(body))
        end
        args = String["curl", "-sS", "-X", "POST",
                       "-H", "Content-Type: application/json"]
        Sys.iswindows() && push!(args, "--ssl-no-revoke")
        api_key === nothing || isempty(api_key) ||
            append!(args, ["-H", "Authorization: Bearer $(api_key)"])
        append!(args, ["--data-binary", "@$input", "-o", output,
                       "-w", "%{http_code}", url])
        code_text = try
            read(Cmd(args), String)
        catch
            throw(PraxoError("PROVIDER_HTTP", "provider request failed"))
        end
        status = tryparse(Int, strip(code_text))
        status === nothing &&
            throw(PraxoError("PROVIDER_HTTP", "provider request failed"))
        response_body = isfile(output) ? read(output, String) : ""
        if status < 200 || status >= 300
            preview = length(response_body) > 512 ?
                response_body[1:512] : response_body
            throw(PraxoError("PROVIDER_HTTP",
                "provider returned HTTP $status: $(preview)"))
        end
        parsed = try
            PraxoCore.Json.parse_json(response_body)
        catch
            throw(PraxoError("PROVIDER_JSON", "provider returned invalid JSON"))
        end
        parsed isa AbstractDict ||
            throw(PraxoError("PROVIDER_JSON", "provider response must be an object"))
        return Dict{String,Any}(String(key) => value for (key, value) in parsed)
    finally
        rm(input; force=true)
        rm(output; force=true)
    end
end

function live_model()
    base_url = get(ENV, "PRAXO_BASE_URL", "http://localhost:11434/v1")
    model_name = get(ENV, "PRAXO_MODEL", "qwen3.5:4b")
    api_key = get(ENV, "PRAXO_API_KEY", "")
    key = isempty(api_key) ? nothing : api_key
    transport = (path, body) -> curl_post(strip(base_url, '/') * path, body, key)
    openai_compatible(base_url, model_name; api_key=key, transport=transport)
end

function run_tests()
    success = run_analysis()
    success.error === nothing || error("success failed: $(sprint(showerror, success.error))")
    success.report !== nothing || error("success returned no report")
    fit = success.report["fit"]
    fit["r_squared"] > 0.99 || error("fit quality too low")
    fit["coefficients"][3] < 0 || error("expected a concave response surface")
    0.0 <= fit["optimum_x"] <= 1.0 || error("optimum outside bounds")
    fit["predicted_yield"] > fit["baseline_mean"] || error("no predicted improvement")
    success.state.reads == 1 || error("read count mismatch")
    success.state.fits == 1 || error("fit count mismatch")
    success.state.writes == 0 || error("success performed a write")
    success.sink.tools == ["load_observations", "fit_response_surface"] ||
        error("unexpected success tool trace")

    direct = run_analysis(mode="direct")
    direct.error isa PraxoError || error("direct publish did not fail")
    direct.error.code == "AGENT_POLICY_DENIED" || error("direct publish was not policy-denied")
    direct.state.writes == 0 || error("direct publish had an effect")

    other = run_analysis(mode="other")
    other.error isa PraxoError || error("other dataset did not fail")
    other.state.reads == 0 || error("other dataset performed a read")

    weak = run_analysis(mode="weak")
    weak.error !== nothing || error("fit-before-load did not fail")
    weak.state.reads == 0 || error("fit-before-load performed a read")
    weak.state.writes == 0 || error("fit-before-load performed a write")

    tenant = run_analysis(tenant="other")
    tenant.error isa PraxoError || error("tenant mismatch did not fail")
    isempty(tenant.sink.tools) || error("tenant mismatch invoked a tool")

    failure = run_analysis(simulate_failure=true)
    failure.error !== nothing || error("dependency failure did not fail")
    failure.state.reads == 1 || error("dependency failure read count mismatch")
    failure.state.fits == 1 || error("dependency failure fit count mismatch")
    failure.state.writes == 0 || error("dependency failure performed a write")

    println("Julia scientific copilot: all checks passed")
end

if "--test" in ARGS
    run_tests()
    exit(0)
end

live = "--live" in ARGS
mode = "--direct" in ARGS ? "direct" :
       "--other" in ARGS ? "other" :
       "--weak" in ARGS ? "weak" : "normal"
tenant = get(ENV, "PRAXO_TENANT", TENANT)
ten_index = findfirst(==("--tenant"), ARGS)
ten_index !== nothing && ten_index < length(ARGS) && (tenant = ARGS[ten_index + 1])
simulate_failure = "--simulate-failure" in ARGS
outcome = run_analysis(live=live, mode=mode, tenant=tenant,
                       simulate_failure=simulate_failure)
if outcome.error !== nothing
    println(stderr, "scientific copilot failed: ",
            sprint(showerror, outcome.error))
    exit(1)
end
println(PraxoCore.Json.stringify(outcome.report))
