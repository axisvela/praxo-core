module Otel

using Dates
using ..Json
using ..Errors
using ..Models
using ..Runtime
import ..Runtime: emit

export OtelSink, otel_sink

const MAX_BODY = 512

struct OtelSink <: AbstractSink
    endpoint::String
    service_name::String
    allowed_data_keys::Vector{String}
    transport::Union{Nothing,Function}
    clock::Function
end

function otel_sink(endpoint::AbstractString;
                   service_name::AbstractString="praxo-core",
                   allowed_data_keys=String[],
                   transport=nothing,
                   clock=nothing)
    name = isempty(strip(String(service_name))) ? "praxo-core" : String(service_name)
    keys = String[String(key) for key in allowed_data_keys]
    return OtelSink(
        String(endpoint),
        name,
        keys,
        transport,
        clock === nothing ? default_clock : clock,
    )
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
    throw(PraxoError("OTEL_HTTP", "otel: invalid clock"))
end

function fnv1a(text::AbstractString, seed::UInt64)
    value = seed
    for byte in codeunits(text)
        value = xor(value, UInt64(byte))
        value *= UInt64(0x100000001b3)
    end
    return value
end

function stable_id(text::AbstractString)
    return lpad(string(fnv1a(text, UInt64(0xcbf29ce484222325)), base=16), 16, '0')
end

function attribute(key::AbstractString, value::AbstractString)
    return Dict{String,Any}(
        "key" => String(key),
        "value" => Dict{String,Any}("stringValue" => String(value)),
    )
end

function text_value(value)
    return value isa AbstractString ? String(value) : Json.stringify(value)
end

function payload(sink::OtelSink, event::Event, stamp::String)
    data_text = event.data === nothing ? "" : Json.stringify(event.data)
    key = string(
        event.session_id, "|",
        something(event.run_id, ""), "|",
        event.type, "|",
        stamp, "|",
        data_text,
    )
    trace_id = stable_id("trace-a:" * key) * stable_id("trace-b:" * key)
    span_id = stable_id("span:" * key)
    attributes = Any[attribute("praxo.event.type", event.type)]
    if !isempty(event.session_id)
        push!(attributes, attribute("praxo.session.id", event.session_id))
    end
    if event.run_id !== nothing && !isempty(event.run_id)
        push!(attributes, attribute("praxo.run.id", event.run_id))
    end
    push!(attributes, attribute("praxo.event.at", stamp))
    if event.data isa AbstractDict
        for name in sink.allowed_data_keys
            haskey(event.data, name) || continue
            push!(attributes, attribute("praxo.event.data." * name,
                                        text_value(event.data[name])))
        end
    end
    span = Dict{String,Any}(
        "traceId" => trace_id,
        "spanId" => span_id,
        "name" => "praxo." * event.type,
        "kind" => 1,
        "startTimeUnixNano" => stamp,
        "endTimeUnixNano" => stamp,
        "attributes" => attributes,
    )
    return Dict{String,Any}(
        "resourceSpans" => Any[
            Dict{String,Any}(
                "resource" => Dict{String,Any}(
                    "attributes" => Any[attribute("service.name", sink.service_name)],
                ),
                "scopeSpans" => Any[
                    Dict{String,Any}(
                        "scope" => Dict{String,Any}("name" => "praxo-core"),
                        "spans" => Any[span],
                    ),
                ],
            ),
        ],
    )
end

function bounded(body::AbstractString)
    text = String(body)
    length(text) > MAX_BODY && (text = first(text, MAX_BODY))
    return strip(text)
end

function response_parts(response)
    if response isa NamedTuple
        return (Int(response.status), String(response.body))
    elseif response isa Tuple
        return (Int(response[1]), String(response[2]))
    elseif response isa AbstractDict
        return (Int(response["status"]), String(get(response, "body", "")))
    end
    throw(PraxoError("OTEL_HTTP", "otel: transport returned an invalid response"))
end

function post(endpoint::String, body::String, headers::Dict{String,String})
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
                       endpoint])
        code_text = try
            read(Cmd(args), String)
        catch
            throw(PraxoError("OTEL_HTTP", "otel request failed"))
        end
        status = tryparse(Int, strip(code_text))
        status === nothing &&
            throw(PraxoError("OTEL_HTTP", "otel request failed"))
        response_body = isfile(output) ? read(output, String) : ""
        return (status=status, body=response_body)
    finally
        rm(input; force=true)
        rm(output; force=true)
    end
end

function emit(sink::OtelSink, event::Event)
    endpoint = strip(sink.endpoint)
    isempty(endpoint) &&
        throw(PraxoError("OTEL_URL", "otel: endpoint is required"))
    seconds, nanos = clock_parts(sink.clock)
    stamp = string(Int(seconds) * 1_000_000_000 + Int(nanos))
    body = Json.stringify(payload(sink, event, stamp))
    headers = Dict{String,String}("content-type" => "application/json")
    response = sink.transport === nothing ?
        post(String(endpoint), body, headers) :
        sink.transport(String(endpoint), body, headers)
    status, response_body = response_parts(response)
    if 200 <= status < 300
        return nothing
    end
    throw(PraxoError("OTEL_HTTP",
        "otel: HTTP $(status): $(bounded(response_body))"))
end

end
