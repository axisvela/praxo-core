module Anthropic

using ..Json
using ..Errors
using ..Models
import ..Models: generate
import ..AgentRuntime: generate_stream

export AnthropicModel, anthropic

struct AnthropicModel <: AbstractModel
    base_url::String
    model::String
    api_key::Union{Nothing,String}
    version::String
    max_tokens::Int
    transport::Union{Nothing,Function}
    stream_transport::Union{Nothing,Function}
end

function anthropic(base_url::AbstractString, model::AbstractString;
                   api_key::Union{Nothing,AbstractString}=nothing,
                   version::AbstractString="2023-06-01",
                   max_tokens::Integer=1024,
                   transport=nothing, stream_transport=nothing)
    return AnthropicModel(
        strip(String(base_url), '/'),
        String(model),
        api_key === nothing ? nothing : String(api_key),
        String(version),
        Int(max_tokens),
        transport,
        stream_transport,
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

function default_stream_transport(adapter::AnthropicModel, path::String,
                                  body::Dict{String,Any})
    isempty(adapter.base_url) &&
        throw(PraxoError("PROVIDER_HTTP", "provider base URL is required"))
    input = tempname()
    try
        open(input, "w") do io
            write(io, Json.stringify(body))
        end
        version = isempty(adapter.version) ? "2023-06-01" : adapter.version
        args = String["curl", "-sS", "-N", "-X", "POST",
                       "-H", "Content-Type: application/json",
                       "-H", "Accept: text/event-stream",
                       "-H", "x-api-key: $(adapter.api_key)",
                       "-H", "anthropic-version: $version"]
        append!(args, ["--data-binary", "@$input",
                       adapter.base_url * path])
        return read(Cmd(args), String)
    finally
        rm(input; force=true)
    end
end

function parse_stream_response(text::AbstractString, on_delta::Function)
    content = IOBuffer()
    calls = Dict{Int,Dict{String,String}}()
    input_tokens = 0
    output_tokens = 0
    cached_tokens = 0
    stop_reason = nothing
    stopped = false
    for raw in split(text, '\n')
        line = strip(raw)
        startswith(line, "data:") || continue
        chunk = strip(line[6:end])
        isempty(chunk) && continue
        event = try
            Json.parse_json(chunk)
        catch
            throw(PraxoError("MODEL_STREAM", "anthropic: invalid stream chunk"))
        end
        event isa AbstractDict || continue
        kind = Json.getstring(event, "type", "")
        if kind == "message_start"
            message = Json.getvalue(event, "message", Dict{String,Any}())
            usage = message isa AbstractDict ?
                Json.getvalue(message, "usage", Dict{String,Any}()) : Dict{String,Any}()
            if usage isa AbstractDict
                input_tokens = Json.getint(usage, "input_tokens", input_tokens)
                cached_tokens = Json.getint(usage, "cache_read_input_tokens", cached_tokens)
            end
        elseif kind == "content_block_start"
            index = Json.getint(event, "index", length(calls)) + 1
            block = Json.getvalue(event, "content_block", Dict{String,Any}())
            if block isa AbstractDict && Json.getstring(block, "type", "") == "tool_use"
                calls[index] = Dict{String,String}(
                    "id" => String(Json.getstring(block, "id", "")),
                    "name" => String(Json.getstring(block, "name", "")),
                    "arguments" => "",
                )
            end
        elseif kind == "content_block_delta"
            index = Json.getint(event, "index", 0) + 1
            delta = Json.getvalue(event, "delta", Dict{String,Any}())
            if delta isa AbstractDict
                delta_type = Json.getstring(delta, "type", "")
                if delta_type == "text_delta"
                    piece = Json.getstring(delta, "text", "")
                    if !isempty(piece)
                        write(content, piece)
                        on_delta(piece)
                    end
                elseif delta_type == "input_json_delta" && haskey(calls, index)
                    calls[index]["arguments"] *= Json.getstring(delta, "partial_json", "")
                end
            end
        elseif kind == "message_delta"
            delta = Json.getvalue(event, "delta", Dict{String,Any}())
            if delta isa AbstractDict
                reason = Json.getstring(delta, "stop_reason", nothing)
                reason === nothing || (stop_reason = reason)
            end
            usage = Json.getvalue(event, "usage", Dict{String,Any}())
            usage isa AbstractDict &&
                (output_tokens = Json.getint(usage, "output_tokens", output_tokens))
        elseif kind == "message_stop"
            stopped = true
        elseif kind == "error"
            throw(PraxoError("MODEL_STREAM", "anthropic: stream error"))
        end
    end
    stopped || stop_reason !== nothing ||
        throw(PraxoError("MODEL_STREAM", "anthropic: stream ended before completion"))
    tool_calls = ToolCall[]
    for index in sort(collect(keys(calls)))
        call = calls[index]
        isempty(call["name"]) && continue
        arguments = Dict{String,Any}()
        if !isempty(call["arguments"])
            parsed = try
                Json.parse_json(call["arguments"])
            catch
                throw(PraxoError("PROVIDER_JSON", "anthropic: invalid tool arguments"))
            end
            parsed isa AbstractDict ||
                throw(PraxoError("PROVIDER_JSON", "anthropic: invalid tool arguments"))
            arguments = Dict{String,Any}(String(key) => value for (key, value) in parsed)
        end
        push!(tool_calls, ToolCall(call["id"], call["name"], arguments))
    end
    return Response(
        message_assistant(String(take!(content)), tool_calls),
        Usage(input_tokens, output_tokens, cached_tokens),
        stop_reason,
    )
end

function generate_stream(adapter::AnthropicModel, request::Request,
                         on_delta::Function)
    adapter.api_key === nothing || isempty(adapter.api_key) &&
        throw(PraxoError("MODEL_CONFIG", "anthropic: API key is required"))
    isempty(adapter.model) &&
        throw(PraxoError("MODEL_CONFIG", "anthropic: model is required"))
    body = payload(adapter, request)
    body["stream"] = true
    text = adapter.stream_transport === nothing ?
        default_stream_transport(adapter, "/v1/messages", body) :
        adapter.stream_transport("/v1/messages", body)
    text isa AbstractString ||
        throw(PraxoError("PROVIDER_HTTP", "anthropic: stream transport must return SSE text"))
    return parse_stream_response(text, on_delta)
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
