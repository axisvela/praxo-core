module OpenAICompatible

using ..Json
using ..Errors
using ..Models
import ..Models: generate
import ..AgentRuntime: generate_stream

export OpenAICompatibleModel, openai_compatible

struct OpenAICompatibleModel <: AbstractModel
    base_url::String
    model::String
    api_key::Union{Nothing,String}
    transport::Union{Nothing,Function}
    stream_transport::Union{Nothing,Function}
end

function openai_compatible(base_url::AbstractString, model::AbstractString;
                           api_key::Union{Nothing,AbstractString}=nothing,
                           transport=nothing, stream_transport=nothing)
    return OpenAICompatibleModel(
        strip(String(base_url), '/'),
        String(model),
        api_key === nothing ? nothing : String(api_key),
        transport,
        stream_transport,
    )
end

function message_payload(message::Message)
    content = message.content === nothing ? "" : message.content
    if isempty(content) && !isempty(message.content_blocks)
        content = join([something(block.text, "")
                        for block in message.content_blocks if block.type == "text"])
    end
    out = Dict{String,Any}("role" => message.role, "content" => content)
    if message.role == Roles.ASSISTANT && !isempty(message.tool_calls)
        out["tool_calls"] = [Dict{String,Any}(
            "id" => call.id,
            "type" => "function",
            "function" => Dict{String,Any}(
                "name" => call.name,
                "arguments" => Json.stringify(call.arguments),
            ),
        ) for call in message.tool_calls]
    end
    if message.role == Roles.TOOL && message.tool_id !== nothing && !isempty(message.tool_id)
        out["tool_call_id"] = message.tool_id
    end
    return out
end

function tool_payload(tool::ToolSpec)
    parameters = tool.parameters === nothing ?
        Dict{String,Any}("type" => "object") : tool.parameters
    return Dict{String,Any}(
        "type" => "function",
        "function" => Dict{String,Any}(
            "name" => tool.name,
            "description" => tool.description,
            "parameters" => parameters,
        ),
    )
end

function payload(adapter::OpenAICompatibleModel, request::Request)
    messages = [message_payload(message) for message in request.messages]
    result = Dict{String,Any}("model" => adapter.model, "messages" => messages)
    if !isempty(request.tools)
        result["tools"] = [tool_payload(tool) for tool in request.tools]
    end
    if request.tool_choice !== nothing && !isempty(request.tool_choice)
        result["tool_choice"] = request.tool_choice
    end
    if request.response_format !== nothing
        result["response_format"] = request.response_format
    end
    if request.temperature != 0.0
        result["temperature"] = request.temperature
    end
    return result
end

function parse_arguments(raw)
    arguments = Dict{String,Any}()
    if raw isa AbstractString
        text = String(raw)
        if !isempty(text)
            parsed = try
                Json.parse_json(text)
            catch
                throw(PraxoError("PROVIDER_JSON", "provider returned invalid tool arguments"))
            end
            parsed isa AbstractDict ||
                throw(PraxoError("PROVIDER_JSON", "provider tool arguments must be an object"))
            arguments = Dict{String,Any}(String(key) => value for (key, value) in parsed)
        end
    elseif raw isa AbstractDict
        arguments = Dict{String,Any}(String(key) => value for (key, value) in raw)
    elseif raw !== nothing
        throw(PraxoError("PROVIDER_JSON", "provider tool arguments must be an object"))
    end
    return arguments
end

function parse_response(data::AbstractDict)
    choices = Json.getarray(data, "choices")
    choice = isempty(choices) ? Dict{String,Any}() : Dict{String,Any}(choices[1])
    wire = Json.getvalue(choice, "message", nothing)
    wire isa AbstractDict || (wire = Dict{String,Any}())
    calls = ToolCall[]
    for item in Json.getarray(wire, "tool_calls")
        item isa AbstractDict || continue
        function_value = Json.getvalue(item, "function", nothing)
        function_value isa AbstractDict || (function_value = Dict{String,Any}())
        arguments = parse_arguments(Json.getvalue(function_value, "arguments", nothing))
        push!(calls, ToolCall(
            String(Json.getstring(item, "id", "")),
            String(Json.getstring(function_value, "name", "")),
            arguments,
        ))
    end
    content = Json.getstring(wire, "content", "")
    usage_value = Json.getvalue(data, "usage", nothing)
    usage_value isa AbstractDict || (usage_value = Dict{String,Any}())
    finish = Json.getstring(choice, "finish_reason", nothing)
    return Response(
        message_assistant(content === nothing ? "" : String(content), calls),
        Usage(Json.getint(usage_value, "prompt_tokens", 0),
              Json.getint(usage_value, "completion_tokens", 0), 0),
        finish === nothing ? nothing : String(finish),
    )
end

function bounded(body::AbstractString)
    return length(body) > 512 ? body[1:512] : String(body)
end

function default_transport(adapter::OpenAICompatibleModel, path::String,
                           body::Dict{String,Any})
    isempty(adapter.base_url) &&
        throw(PraxoError("PROVIDER_HTTP", "provider base URL is required"))
    input = tempname()
    output = tempname()
    try
        open(input, "w") do io
            write(io, Json.stringify(body))
        end
        args = String["curl", "-sS", "-X", "POST", "-H", "Content-Type: application/json"]
        if adapter.api_key !== nothing && !isempty(adapter.api_key)
            append!(args, ["-H", "Authorization: Bearer $(adapter.api_key)"])
        end
        append!(args, ["--data-binary", "@$input", "-o", output, "-w", "%{http_code}",
                       adapter.base_url * path])
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
            throw(PraxoError("PROVIDER_HTTP",
                "provider returned HTTP $status: $(bounded(response_body))"))
        end
        parsed = try
            Json.parse_json(response_body)
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

function generate(adapter::OpenAICompatibleModel, request::Request)
    body = payload(adapter, request)
    path = "/chat/completions"
    data = adapter.transport === nothing ?
        default_transport(adapter, path, body) :
        adapter.transport(path, body)
    data isa AbstractDict ||
        throw(PraxoError("PROVIDER_JSON", "provider response must be an object"))
    return parse_response(data)
end

function default_stream_transport(adapter::OpenAICompatibleModel, path::String,
                                  body::Dict{String,Any})
    isempty(adapter.base_url) &&
        throw(PraxoError("PROVIDER_HTTP", "provider base URL is required"))
    input = tempname()
    try
        open(input, "w") do io
            write(io, Json.stringify(body))
        end
        args = String["curl", "-sS", "-N", "-X", "POST",
                       "-H", "Content-Type: application/json",
                       "-H", "Accept: text/event-stream"]
        if adapter.api_key !== nothing && !isempty(adapter.api_key)
            append!(args, ["-H", "Authorization: Bearer $(adapter.api_key)"])
        end
        append!(args, ["--data-binary", "@$input", adapter.base_url * path])
        text = try
            read(Cmd(args), String)
        catch
            throw(PraxoError("PROVIDER_HTTP", "provider request failed"))
        end
        return text
    finally
        rm(input; force=true)
    end
end

function parse_sse_response(text::AbstractString, on_delta::Function)
    content = IOBuffer()
    calls = Dict{Int,Dict{String,String}}()
    input_tokens = 0
    output_tokens = 0
    finish_reason = nothing
    done = false
    for raw in split(text, '\n')
        line = strip(raw)
        startswith(line, "data:") || continue
        chunk = strip(line[6:end])
        isempty(chunk) && continue
        if chunk == "[DONE]"
            done = true
            break
        end
        event = try
            Json.parse_json(chunk)
        catch
            throw(PraxoError("MODEL_STREAM", "invalid SSE packet"))
        end
        event isa AbstractDict || continue
        usage = Json.getvalue(event, "usage", nothing)
        if usage isa AbstractDict
            input_tokens = Json.getint(usage, "prompt_tokens", 0)
            output_tokens = Json.getint(usage, "completion_tokens", 0)
        end
        for choice in Json.getarray(event, "choices")
            choice isa AbstractDict || continue
            delta = Json.getvalue(choice, "delta", nothing)
            if delta isa AbstractDict
                piece = Json.getstring(delta, "content", nothing)
                if piece !== nothing && !isempty(piece)
                    write(content, piece)
                    on_delta(piece)
                end
                for item in Json.getarray(delta, "tool_calls")
                    item isa AbstractDict || continue
                    index = Json.getint(item, "index", length(calls))
                    call = get!(calls, index,
                        Dict{String,String}("id" => "", "name" => "", "arguments" => ""))
                    id = Json.getstring(item, "id", nothing)
                    id === nothing || (call["id"] *= id)
                    function_value = Json.getvalue(item, "function", nothing)
                    if function_value isa AbstractDict
                        name = Json.getstring(function_value, "name", nothing)
                        name === nothing || (call["name"] *= name)
                        arguments = Json.getstring(function_value, "arguments", nothing)
                        arguments === nothing || (call["arguments"] *= arguments)
                    end
                end
            end
            reason = Json.getstring(choice, "finish_reason", nothing)
            if reason !== nothing
                finish_reason = reason
                done = true
            end
        end
    end
    done || throw(PraxoError("MODEL_STREAM", "stream ended before completion"))
    tool_calls = ToolCall[]
    for index in sort(collect(keys(calls)))
        call = calls[index]
        isempty(call["name"]) && continue
        arguments = Dict{String,Any}()
        if !isempty(call["arguments"])
            parsed = try
                Json.parse_json(call["arguments"])
            catch
                throw(PraxoError("PROVIDER_JSON", "provider returned invalid tool arguments"))
            end
            parsed isa AbstractDict ||
                throw(PraxoError("PROVIDER_JSON", "provider returned invalid tool arguments"))
            arguments = Dict{String,Any}(String(key) => value for (key, value) in parsed)
        end
        push!(tool_calls, ToolCall(call["id"], call["name"], arguments))
    end
    return Response(
        message_assistant(String(take!(content)), tool_calls),
        Usage(input_tokens, output_tokens, 0),
        finish_reason,
    )
end

function generate_stream(adapter::OpenAICompatibleModel, request::Request,
                         on_delta::Function)
    body = payload(adapter, request)
    body["stream"] = true
    path = "/chat/completions"
    text = adapter.stream_transport === nothing ?
        default_stream_transport(adapter, path, body) :
        adapter.stream_transport(path, body)
    text isa AbstractString ||
        throw(PraxoError("PROVIDER_HTTP", "stream transport must return SSE text"))
    return parse_sse_response(text, on_delta)
end

end
