module Delegation

using Dates
using ..Errors

export SubagentRequest, SubagentResult, SubagentTask, SubagentRunner
export subagent_request, subagent_result, subagent_run

const SubagentRunner = Function

struct SubagentRequest
    parent_session_id::String
    agent_id::String
    prompt::String
    mode::String
end

function SubagentRequest(parent_session_id::AbstractString, agent_id::AbstractString,
                         prompt::AbstractString, mode::AbstractString="isolated")
    normalized = isempty(strip(String(mode))) ? "isolated" : String(mode)
    return SubagentRequest(String(parent_session_id), String(agent_id),
                           String(prompt), normalized)
end

function SubagentRequest(; parent_session_id::AbstractString="",
                         agent_id::AbstractString="",
                         prompt::AbstractString="",
                         mode::AbstractString="isolated")
    return SubagentRequest(parent_session_id, agent_id, prompt, mode)
end

subagent_request(parent_session_id::AbstractString, agent_id::AbstractString,
                 prompt::AbstractString, mode::AbstractString="isolated") =
    SubagentRequest(parent_session_id, agent_id, prompt, mode)

subagent_request(; kwargs...) = SubagentRequest(; kwargs...)

struct SubagentResult
    task_id::String
    agent_id::String
    output::String
end

function SubagentResult(task_id::AbstractString, agent_id::AbstractString,
                        output::AbstractString)
    return SubagentResult(String(task_id), String(agent_id), String(output))
end

function SubagentResult(; task_id::AbstractString="", agent_id::AbstractString="",
                        output::AbstractString="")
    return SubagentResult(task_id, agent_id, output)
end

subagent_result(; kwargs...) = SubagentResult(; kwargs...)
subagent_result(output::AbstractString) = SubagentResult("", "", output)

struct SubagentTask
    id::String
    parent_session_id::String
    agent_id::String
    mode::String
    status::String
    output::String
    error::String
    created_at::String
    updated_at::String
end

function default_clock()
    now = time()
    seconds = floor(Int, now)
    nanos = round(Int, (now - seconds) * 1_000_000_000)
    return normalize_time(seconds, nanos)
end

function normalize_time(seconds::Integer, nanos::Integer)
    value = Int(seconds)
    fraction = Int(nanos)
    value += div(fraction, 1_000_000_000)
    fraction = mod(fraction, 1_000_000_000)
    return (value, fraction)
end

function clock_parts(clock)
    clock === nothing && return default_clock()
    value = clock()
    if (value isa Tuple || value isa NamedTuple) && length(value) == 2
        return normalize_time(value[1], value[2])
    elseif value isa DateTime
        seconds = Dates.datetime2unix(value)
        nanos = Dates.millisecond(value) * 1_000_000
        return normalize_time(seconds, nanos)
    elseif value isa Real
        seconds = floor(Int, value)
        nanos = round(Int, (value - seconds) * 1_000_000_000)
        return normalize_time(seconds, nanos)
    end
    throw(PraxoError("SUBAGENT_ERROR", "agent: invalid clock"))
end

function rfc3339_nano(seconds::Integer, nanos::Integer)
    at = Dates.unix2datetime(Int(seconds))
    return string(
        Dates.format(at, "yyyy-mm-ddTHH:MM:SS"),
        ".",
        lpad(string(Int(nanos)), 9, '0'),
        "Z",
    )
end

function timestamp(clock)
    seconds, nanos = clock_parts(clock)
    return rfc3339_nano(seconds, nanos)
end

function subagent_run(runner, request::SubagentRequest; clock=nothing)
    runner === nothing &&
        throw(PraxoError("SUBAGENT_INVALID", "agent: subagent runner is required"))
    (isempty(request.parent_session_id) || isempty(request.agent_id)) &&
        throw(PraxoError("SUBAGENT_INVALID",
            "agent: subagent parent session and agent id are required"))
    created = timestamp(clock)
    mode = request.mode == "fork" ? "fork" : "isolated"
    try
        result = runner(request)
        return SubagentTask(
            "subagent",
            request.parent_session_id,
            request.agent_id,
            mode,
            "completed",
            result.output,
            "",
            created,
            timestamp(clock),
        )
    catch caught
        code = caught isa PraxoError ? caught.code : "SUBAGENT_ERROR"
        return SubagentTask(
            "subagent",
            request.parent_session_id,
            request.agent_id,
            mode,
            "failed",
            "",
            code,
            created,
            timestamp(clock),
        )
    end
end

end
