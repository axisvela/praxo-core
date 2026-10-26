module ToolCallParser

using ..Json

export ParsedToolCall, parse_toolcall, strip_markup, parse_input_json

struct ParsedToolCall
    call_id::String
    name::String
    input::Dict{String,Any}
    operation::String
    resource::String
    risk::String
    reason::String
    idempotency_key::String
end

ParsedToolCall(name::String, input::Dict{String,Any}) = ParsedToolCall(
    "", name, input, "", "", "", "", ""
)

function parse_toolcall(content::AbstractString)
    call = parse_json_call(content)
    call === nothing && (call = parse_xml(content))
    call === nothing && (call = parse_tag(content))
    call === nothing && (call = parse_plain(content))
    if call !== nothing
        call = ParsedToolCall(
            "tc-$(round(Int, time() * 1000))",
            call.name,
            call.input,
            call.operation,
            call.resource,
            call.risk,
            call.reason,
            call.idempotency_key,
        )
    end
    return call
end

function strip_markup(content::AbstractString)
    patterns = [
        r"<tool_call\s+name=\"[^\"]+\"\s*>.*?(?:</tool_call>|$)"s,
        r"<tool_call_invoke>.*?(?:</tool_call_invoke>|$)"s,
        r"<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{.*?(?:</[a-zA-Z][\w.-]*>|$)"s,
    ]
    output = content
    for pattern in patterns
        output = replace(output, pattern => "")
    end
    output = replace(output, r"\n{3,}" => "\n\n")
    return strip(output)
end

function parse_input_json(raw::AbstractString)
    try
        value = Json.parse_json(strip(raw))
        if value isa AbstractDict
            return Dict{String,Any}(String(key) => item for (key, item) in value)
        end
    catch
    end
    try
        value = Json.parse_json(strip(replace(raw, "\\" => "\\\\")))
        if value isa AbstractDict
            return Dict{String,Any}(String(key) => item for (key, item) in value)
        end
    catch
    end
    return nothing
end

function parse_json_call(content::AbstractString)
    try
        root = Json.parse_json(content)
        if root isa AbstractDict && get(root, "name", nothing) isa AbstractString
            name = String(root["name"])
            isempty(name) && return nothing
            input = get(root, "input", Dict{String,Any}())
            input = input isa AbstractDict ? Dict{String,Any}(String(k) => v for (k, v) in input) : Dict{String,Any}()
            return ParsedToolCall(
                "",
                name,
                input,
                string(get(root, "operation", "")),
                string(get(root, "resource", "")),
                string(get(root, "risk", "")),
                string(get(root, "reason", "")),
                string(get(root, "idempotency_key", "")),
            )
        end
    catch
    end
    return nothing
end

function parse_xml(content::AbstractString)
    match_result = match(r"<tool_call\s+name=\"([^\"]+)\"\s*>\s*(.*?)\s*</tool_call>"s, content)
    match_result === nothing && return nothing
    input = parse_input_json(something(match_result.captures[2], ""))
    input === nothing && return nothing
    return ParsedToolCall(String(match_result.captures[1]), input)
end

function parse_tag(content::AbstractString)
    pattern = r"<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{.*?)\s*(?:</[a-zA-Z][\w.-]*>|$)"s
    match_result = match(pattern, content)
    match_result === nothing && return nothing
    input = parse_input_json(something(match_result.captures[2], ""))
    input === nothing && return nothing
    return ParsedToolCall(String(match_result.captures[1]), input)
end

function parse_plain(content::AbstractString)
    match_result = match(r"(?m)^\s*([a-zA-Z][\w.-]*)\s+(\{.*\})\s*$", content)
    match_result === nothing && return nothing
    name = String(match_result.captures[1])
    occursin(".", name) || return nothing
    input = parse_input_json(something(match_result.captures[2], ""))
    input === nothing && return nothing
    return ParsedToolCall(name, input)
end

end
