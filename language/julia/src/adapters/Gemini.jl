module Gemini

using ..Json
using ..Errors
using ..Models
import ..Models: generate

export GeminiModel, gemini

struct GeminiModel <: AbstractModel
    base_url::String
    model::String
    api_key::Union{Nothing,String}
    max_output_tokens::Int
    transport::Union{Nothing,Function}
end

function gemini(base_url::AbstractString, model::AbstractString;
                api_key::Union{Nothing,AbstractString}=nothing,
                max_output_tokens::Integer=0,
                transport=nothing)
    return GeminiModel(
        strip(String(base_url), '/'),
        String(model),
        api_key === nothing ? nothing : String(api_key),
        Int(max_output_tokens),
        transport,
    )
end

function message_parts(message::Message)
    parts = Any[]
    if message.content !== nothing && !isempty(message.content)
        push!(parts, Dict{String,Any}("text" => message.content))
    end
    for block in message.content_blocks
        if block.type == "text" && block.text !== nothing && !isempty(block.text)
            push!(parts, Dict{String,Any}("text" => block.text))
        end
    end
    for call in message.tool_calls
        push!(parts, Dict{String,Any}(
            "functionCall" => Dict{String,Any}(
                "name" => call.name,
                "args" => call.arguments,
            ),
        ))
    end
    return parts
end

function build_contents(messages)
    system = Any[]
    contents = Any[]
    pending = Any[]
    names = Dict{String,String}()
    flush() = begin
        if !isempty(pending)
            push!(contents, Dict{String,Any}("role" => "user", "parts" => pending))
            empty!(pending)
        end
    end
    for message in messages
        if message.role == Roles.SYSTEM
            if message.content !== nothing && !isempty(message.content)
                push!(system, Dict{String,Any}("text" => message.content))
            end
        elseif message.role == Roles.TOOL
            name_value = get(names, something(message.tool_id, ""), something(message.tool_id, "tool"))
            push!(pending, Dict{String,Any}(
                "functionResponse" => Dict{String,Any}(
                    "name" => name_value,
                    "response" => Dict{String,Any}("result" => something(message.content, "")),
                ),
            ))
        else
            flush()
            parts = message_parts(message)
            if !isempty(parts)
                role = message.role == Roles.ASSISTANT ? "model" : "user"
                push!(contents, Dict{String,Any}("role" => role, "parts" => parts))
            end
            for call in message.tool_calls
                if !isempty(call.id) && !isempty(call.name)
                    names[call.id] = call.name
                end
            end
        end
    end
    flush()
    return system, contents
end

function payload(adapter::GeminiModel, request::Request)
    system, contents = build_contents(request.messages)
    result = Dict{String,Any}("contents" => contents)
    isempty(system) || (result["system_instruction"] = Dict{String,Any}("parts" => system))
    if !isempty(request.tools)
        result["tools"] = [Dict{String,Any}(
            "functionDeclarations" => [Dict{String,Any}(
                "name" => tool.name,
                "description" => tool.description,
                "parameters" => tool.parameters === nothing ?
                    Dict{String,Any}("type" => "object") : tool.parameters,
            ) for tool in request.tools],
        )]
        result["toolConfig"] = Dict{String,Any}(
            "functionCallingConfig" => Dict{String,Any}(
                "mode" => request.tool_choice == "required" ? "ANY" :
                    request.tool_choice == "none" ? "NONE" : "AUTO",
            ),
        )
    end
    if request.temperature != 0.0 || adapter.max_output_tokens > 0
        result["generationConfig"] = Dict{String,Any}(
            "temperature" => request.temperature,
            "maxOutputTokens" => adapter.max_output_tokens,
        )
    end
    return result
end

function parse_response(data::AbstractDict)
    haskey(data, "error") &&
        throw(PraxoError("PROVIDER_HTTP", "gemini: provider error"))
    candidates = Json.getarray(data, "candidates")
    isempty(candidates) &&
        throw(PraxoError("PROVIDER_HTTP", "gemini: empty response"))
    candidate = Dict{String,Any}(candidates[1])
    content = Json.getvalue(candidate, "content", Dict{String,Any}())
    parts = Json.getarray(content, "parts")
    text = IOBuffer()
    calls = ToolCall[]
    for part in parts
        part isa AbstractDict || continue
        value = Json.getstring(part, "text", "")
        isempty(value) || write(text, value)
        call = Json.getvalue(part, "functionCall", nothing)
        if call isa AbstractDict
            push!(calls, ToolCall(
                "call-$(length(calls) + 1)",
                String(Json.getstring(call, "name", "")),
                Dict{String,Any}(String(k) => v for (k, v) in
                    Json.getvalue(call, "args", Dict{String,Any}())),
            ))
        end
    end
    usage = Json.getvalue(data, "usageMetadata", Dict{String,Any}())
    usage isa AbstractDict || (usage = Dict{String,Any}())
    finish = Json.getstring(candidate, "finishReason", nothing)
    return Response(
        message_assistant(String(take!(text)), calls),
        Usage(Json.getint(usage, "promptTokenCount", 0),
              Json.getint(usage, "candidatesTokenCount", 0),
              Json.getint(usage, "cachedContentTokenCount", 0)),
        finish === nothing ? nothing : String(finish),
    )
end

function default_transport(adapter::GeminiModel, path::String,
                           body::Dict{String,Any})
    isempty(adapter.base_url) &&
        throw(PraxoError("PROVIDER_HTTP", "provider base URL is required"))
    input = tempname()
    output = tempname()
    try
        open(input, "w") do io
            write(io, Json.stringify(body))
        end
        args = String["curl", "-sS", "-X", "POST",
            "-H", "Content-Type: application/json",
            "-H", "x-goog-api-key: $(something(adapter.api_key, ""))",
            "--data-binary", "@$input", "-o", output, "-w", "%{http_code}",
            adapter.base_url * path]
        code_text = try
            read(Cmd(args), String)
        catch
            throw(PraxoError("PROVIDER_HTTP", "provider request failed"))
        end
        status = tryparse(Int, strip(code_text))
        status === nothing &&
            throw(PraxoError("PROVIDER_HTTP", "provider request failed"))
        response_body = read(output, String)
        (status < 200 || status >= 300) &&
            throw(PraxoError("PROVIDER_HTTP",
                "provider returned HTTP $status: $(first(response_body, 512))"))
        parsed = try
            Json.parse_json(response_body)
        catch
            throw(PraxoError("PROVIDER_JSON", "provider returned invalid JSON"))
        end
        parsed isa AbstractDict ||
            throw(PraxoError("PROVIDER_JSON", "provider returned invalid JSON"))
        return parsed
    finally
        rm(input; force=true)
        rm(output; force=true)
    end
end

function generate(adapter::GeminiModel, request::Request)
    adapter.api_key === nothing &&
        throw(PraxoError("MODEL_CONFIG", "gemini: API key is required"))
    isempty(adapter.model) &&
        throw(PraxoError("MODEL_CONFIG", "gemini: model is required"))
    body = payload(adapter, request)
    path = "/v1beta/models/$(adapter.model):generateContent"
    data = adapter.transport === nothing ?
        default_transport(adapter, path, body) : adapter.transport(path, body)
    data isa AbstractDict ||
        throw(PraxoError("PROVIDER_JSON", "provider returned invalid JSON"))
    return parse_response(Dict{String,Any}(data))
end

end
