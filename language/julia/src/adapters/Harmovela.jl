module Harmovela

using Dates
using ..Json
using ..Errors
using ..Models
using ..Runtime
import ..Runtime: emit

export HarmovelaSink, harmovela_sink

const MAX_BODY = 1024

struct HarmovelaSink <: AbstractSink
    base_url::String
    source::String
    spec_version::String
    transport::Union{Nothing,Function}
    clock::Function
end

function harmovela_sink(base_url::AbstractString;
                        source::AbstractString="praxo-core",
                        spec_version::AbstractString="0.2",
                        transport=nothing,
                        clock=nothing)
    return HarmovelaSink(
        rstrip(String(base_url), '/'),
        isempty(String(source)) ? "praxo-core" : String(source),
        isempty(String(spec_version)) ? "0.2" : String(spec_version),
        transport,
        clock === nothing ? default_clock : clock,
    )
end

function default_clock()
    now = time()
    seconds = floor(Int, now)
    nanos = round(Int, (now - seconds) * 1_000_000_000)
    if nanos >= 1_000_000_000
        seconds += 1
        nanos -= 1_000_000_000
    end
    return (seconds, nanos)
end

function normalize_time(seconds::Integer, nanos::Integer)
    value = Int(seconds)
    fraction = Int(nanos)
    value += div(fraction, 1_000_000_000)
    fraction = mod(fraction, 1_000_000_000)
    return (value, fraction)
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

function event_id(event::Event, stamp::Integer)
    prefix = event.run_id === nothing ? "" : event.run_id
    if isempty(prefix)
        prefix = event.session_id
    end
    if isempty(prefix)
        prefix = "event"
    end
    return string(prefix, "-", stamp)
end

function payload(event::Event)
    out = Dict{String,Any}()
    if event.data !== nothing
        for (key, value) in event.data
            out[String(key)] = value
        end
    end
    if !isempty(event.session_id)
        out["session_id"] = event.session_id
    end
    if event.run_id !== nothing && !isempty(event.run_id)
        out["run_id"] = event.run_id
    end
    return out
end

function bounded(body::AbstractString)
    return length(body) > MAX_BODY ? first(body, MAX_BODY) : String(body)
end

function response_parts(response)
    if response isa NamedTuple
        return (Int(response.status), String(response.body))
    elseif response isa Tuple
        return (Int(response[1]), String(response[2]))
    elseif response isa AbstractDict
        return (Int(response["status"]), String(get(response, "body", "")))
    end
    throw(PraxoError("HARMOVELA_HTTP", "harmovela: transport returned an invalid response"))
end

function post(base_url::String, path::String, body::String,
              headers::Dict{String,String})
    input = tempname()
    output = tempname()
    try
        open(input, "w") do io
            write(io, body)
        end
        args = String["curl", "-sS", "-X", "POST"]
        for (key, value) in headers
            append!(args, ["-H", "$(key): $(value)"])
        end
        append!(args, ["--data-binary", "@$input", "-o", output, "-w", "%{http_code}",
                       base_url * path])
        code_text = try
            read(Cmd(args), String)
        catch
            throw(PraxoError("HARMOVELA_HTTP", "harmovela request failed"))
        end
        status = tryparse(Int, strip(code_text))
        status === nothing &&
            throw(PraxoError("HARMOVELA_HTTP", "harmovela request failed"))
        response_body = isfile(output) ? read(output, String) : ""
        return (status=status, body=response_body)
    finally
        rm(input; force=true)
        rm(output; force=true)
    end
end

function emit(sink::HarmovelaSink, event::Event)
    isempty(sink.base_url) &&
        throw(PraxoError("HARMOVELA_URL", "harmovela: base URL is required"))
    seconds, nanos = normalize_time(sink.clock()...)
    envelope = Dict{String,Any}(
        "spec_version" => sink.spec_version,
        "id" => event_id(event, seconds * 1_000_000_000 + nanos),
        "type" => event.type,
        "source" => sink.source,
        "created_at" => rfc3339_nano(seconds, nanos),
        "payload" => payload(event),
    )
    body = Json.stringify(envelope)
    headers = Dict{String,String}("content-type" => "application/json")
    response = sink.transport === nothing ?
        post(sink.base_url, "/events", body, headers) :
        sink.transport("/events", body, headers)
    status, response_body = response_parts(response)
    if 200 <= status < 300
        return nothing
    end
    return throw(PraxoError("HARMOVELA_HTTP",
        "harmovela: HTTP $(status): $(bounded(response_body))"))
end

end
