module Anthropic

using ..Json
using ..Errors
using ..Models
import ..Models: generate

export AnthropicModel, anthropic

struct AnthropicModel <: AbstractModel
    base_url::String
    model::String
    api_key::Union{Nothing,String}
    version::String
    max_tokens::Int
    transport::Union{Nothing,Function}
end

function anthropic(base_url::AbstractString, model::AbstractString;
                   api_key::Union{Nothing,AbstractString}=nothing,
                   version::AbstractString="2023-06-01",
                   max_tokens::Integer=1024,
                   transport=nothing)
    return AnthropicModel(
        strip(String(base_url), '/'),
        String(model),
        api_key === nothing ? nothing : String(api_key),
        String(version),
        Int(max_tokens),
        transport,
    )
end

function message_content(message::Message)
    content = Any[]
    if message.content !== nothing && !isempty(message.content)
        push!(content, Dict{String,Any}("type" => "text", "text" => message.content))
    end
    for block in message.content_blocks
        if block.type == "text" && block.text !== nothing && !isempty(block.text)
            push!(content, Dict{String,Any}("type" => "text", "text" => block.text))
        end
    end
    for call in message.tool_calls
        push!(content, Dict{String,Any}(
            "type" => "tool_use",
            "id" => call.id,
            "name" => call.name,
            "input" => call.arguments,
        ))
    end
    return content
end

function build_messages(messages)
    system = String[]
    out = Any[]
    pending = Any[]
    flush() = begin
        if !isempty(pending)
            push!(out, Dict{String,Any}("role" => "user", "content" => pending))
            empty!(pending)
        end
    end
    for message in messages
        if message.role == Roles.SYSTEM
            if message.content !== nothing && !isempty(message.content)
                push!(system, message.content)
            end
        elseif message.role == Roles.TOOL
            push!(pending, Dict{String,Any}(
                "type" => "tool_result",
                "tool_use_id" => something(message.tool_id, ""),
                "content" => something(message.content, ""),
            ))
        else
            flush()
            content = message_content(message)
            if !isempty(content)
                push!(out, Dict{String,Any}("role" => message.role, "content" => content))
            end
        end
    end
    flush()
    return join(system, "\n\n"), out
end

function payload(adapter::AnthropicModel, request::Request)
    system, messages = build_messages(request.messages)
    result = Dict{String,Any}(
        "model" => adapter.model,
        "max_tokens" => adapter.max_tokens,
        "messages" => messages,
    )
    isempty(system) || (result["system"] = system)
    if !isempty(request.tools)
        result["tools"] = [Dict{String,Any}(
            "name" => tool.name,
            "description" => tool.description,
            "input_schema" => tool.parameters === nothing ?
                Dict{String,Any}("type" => "object") : tool.parameters,
        ) for tool in request.tools]
        if request.tool_choice !== nothing
            choice = request.tool_choice == "auto" ? "auto" :
                request.tool_choice == "required" ? "any" :
                request.tool_choice == "none" ? "none" : nothing
            choice === nothing ||
                (result["tool_choice"] = Dict{String,Any}("type" => choice))
        end
    end
    request.temperature == 0.0 || (result["temperature"] = request.temperature)
    return result
end

function parse_response(data::AbstractDict)
    haskey(data, "error") &&
        throw(PraxoError("PROVIDER_HTTP", "anthropic: provider error"))
    text = IOBuffer()
    calls = ToolCall[]
    for block in Json.getarray(data, "content")
        block isa AbstractDict || continue
        kind = Json.getstring(block, "type", "")
        if kind == "text"
            write(text, Json.getstring(block, "text", ""))
        elseif kind == "tool_use"
            push!(calls, ToolCall(
                String(Json.getstring(block, "id", "")),
                String(Json.getstring(block, "name", "")),
                Json.getvalue(block, "input", Dict{String,Any}()),
            ))
        end
    end
    usage = Json.getvalue(data, "usage", Dict{String,Any}())
    usage isa AbstractDict || (usage = Dict{String,Any}())
    finish = Json.getstring(data, "stop_reason", nothing)
    return Response(
        message_assistant(String(take!(text)), calls),
        Usage(Json.getint(usage, "input_tokens", 0),
              Json.getint(usage, "output_tokens", 0),
              Json.getint(usage, "cache_read_input_tokens", 0)),
        finish === nothing ? nothing : String(finish),
    )
end

function default_transport(adapter::AnthropicModel, path::String,
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
            "-H", "x-api-key: $(something(adapter.api_key, ""))",
            "-H", "anthropic-version: $(adapter.version)",
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

function generate(adapter::AnthropicModel, request::Request)
    adapter.api_key === nothing &&
        throw(PraxoError("MODEL_CONFIG", "anthropic: API key is required"))
    isempty(adapter.model) &&
        throw(PraxoError("MODEL_CONFIG", "anthropic: model is required"))
    body = payload(adapter, request)
    data = adapter.transport === nothing ?
        default_transport(adapter, "/v1/messages", body) :
        adapter.transport("/v1/messages", body)
    data isa AbstractDict ||
        throw(PraxoError("PROVIDER_JSON", "provider returned invalid JSON"))
    return parse_response(Dict{String,Any}(data))
end

end
