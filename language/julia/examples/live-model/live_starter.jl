push!(LOAD_PATH, "language/julia/src")
using PraxoCore
using Dates

const DEFAULT_BASE_URL = "http://localhost:11434/v1"
const DEFAULT_MODEL = "qwen3.5:4b"
const DEFAULT_PROMPT =
    "What time is it? Use get_time with zone set to utc and reply with the time."

function env_or(name::String, fallback::String)
    value = get(ENV, name, "")
    return isempty(value) ? fallback : value
end

function get_time(args::Dict{String,Any})
    zone = get(args, "zone", "utc")
    if zone == "local"
        return Dates.format(Dates.now(), dateformat"yyyy-mm-ddTHH:MM:SS")
    end
    return Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SS") * "Z"
end

function get_time_schema()
    return Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "zone" => Dict{String,Any}(
                "type" => "string",
                "enum" => ["utc", "local"],
                "description" => "utc or local; defaults to utc",
            ),
        ),
    )
end

function inject_tool_schema(handler)
    return function (request)
        request.tools = [ToolSpec(
            "get_time",
            "Return the current time in ISO 8601 format for the requested zone.",
            get_time_schema(),
            "read",
        )]
        return handler(request)
    end
end

struct AllowGetTime <: AbstractPolicy end

function PraxoCore.authorize(::AllowGetTime, action::Action)
    if action.kind == "model.generate"
        return Decision(true, "model generation")
    elseif action.kind == "tool.invoke"
        if action.tool_name == "get_time"
            return Decision(true, "get_time is permitted")
        end
        return Decision(false, "only get_time is permitted")
    end
    return Decision(false, "unsupported action")
end

function main()
    base_url = env_or("PRAXO_BASE_URL", DEFAULT_BASE_URL)
    model_name = env_or("PRAXO_MODEL", DEFAULT_MODEL)
    api_key = get(ENV, "PRAXO_API_KEY", "")
    prompt = env_or("PRAXO_PROMPT", DEFAULT_PROMPT)

    adapter = openai_compatible(base_url, model_name;
                                api_key = isempty(api_key) ? nothing : api_key)
    registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(registry, FuncTool(
        "get_time",
        "Return the current time in ISO 8601 format for the requested zone.",
        get_time,
    ))
    options = AgentOptions(adapter)
    options.tools = registry
    options.system_prompt =
        "You are a concise assistant. Use the provided tools when they help."
    options.max_steps = 4
    options.allowed_tools = ["get_time"]
    options.policy = AllowGetTime()
    options.require_policy = true
    options.require_tool_scope = true
    options.model_middleware = Function[inject_tool_schema]

    try
        result = run_agent(Agent(options), Session("live-model"), prompt)
        println(result.output)
    catch error
        println(stderr, "live model run failed: ", sprint(showerror, error), "\n\n",
                "Check PRAXO_BASE_URL (", base_url, "), PRAXO_MODEL (", model_name,
                "), and PRAXO_API_KEY")
        exit(1)
    end
end

main()
