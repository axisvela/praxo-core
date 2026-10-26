module Models

export ContentBlock, ToolCall, Message, ToolSpec, Usage, Request, Response
export Session, RunResult, MemoryRecord, PathGrant, Action, Decision, Event, Roles, StreamKinds
export AbstractModel, generate, message_dict, plus, message_text, message_assistant, message_tool

module Roles
const SYSTEM = "system"
const USER = "user"
const ASSISTANT = "assistant"
const TOOL = "tool"
end

const StreamKinds = ["values", "updates", "messages", "tasks", "debug", "checkpoint"]

struct ContentBlock
    type::String
    text::Union{Nothing,String}
    image_url::Union{Nothing,String}
    data::Union{Nothing,String}
end

ContentBlock(text::String) = ContentBlock("text", text, nothing, nothing)

mutable struct ToolCall
    id::String
    name::String
    arguments::Dict{String,Any}
end

ToolCall(name::String, arguments::Dict{String,Any}) = ToolCall("", name, arguments)

struct Message
    role::String
    content::Union{Nothing,String}
    content_blocks::Vector{ContentBlock}
    tool_calls::Vector{ToolCall}
    tool_id::Union{Nothing,String}
end

Message(role::String, content::Union{Nothing,String}) =
    Message(role, content, ContentBlock[], ToolCall[], nothing)

function Message(; role::String, content::Union{Nothing,String}=nothing,
                 content_blocks::Vector{ContentBlock}=ContentBlock[],
                 tool_calls::Vector{ToolCall}=ToolCall[],
                 tool_id::Union{Nothing,String}=nothing)
    Message(role, content, content_blocks, tool_calls, tool_id)
end

message_text(role::String, content::String) = Message(role, content)
message_assistant(content::String, calls::Vector{ToolCall}=ToolCall[]) =
    Message(Roles.ASSISTANT, content, ContentBlock[], calls, nothing)
message_tool(content::String, tool_id::String) =
    Message(Roles.TOOL, content, ContentBlock[], ToolCall[], tool_id)

function message_dict(message::Message)
    out = Dict{String,Any}("role" => message.role)
    message.content === nothing || (out["content"] = message.content)
    if !isempty(message.content_blocks)
        out["contentBlocks"] = [Dict{String,Any}(
            "type" => block.type,
            "text" => block.text,
            "image_url" => block.image_url,
            "data" => block.data,
        ) for block in message.content_blocks]
        for item in out["contentBlocks"]
            for key in ("text", "image_url", "data")
                item[key] === nothing && delete!(item, key)
            end
        end
    end
    if !isempty(message.tool_calls)
        out["toolCalls"] = [Dict{String,Any}(
            "id" => call.id,
            "name" => call.name,
            "arguments" => call.arguments,
        ) for call in message.tool_calls]
    end
    message.tool_id === nothing || (out["toolId"] = message.tool_id)
    out
end

struct ToolSpec
    name::String
    description::String
    parameters::Union{Nothing,Dict{String,Any}}
    risk::Union{Nothing,String}
end

ToolSpec(name::String, description::String="") = ToolSpec(name, description, nothing, nothing)

mutable struct Usage
    input_tokens::Int
    output_tokens::Int
    cached_tokens::Int
end

Usage() = Usage(0, 0, 0)

function plus(left::Usage, right::Usage)
    Usage(left.input_tokens + right.input_tokens,
          left.output_tokens + right.output_tokens,
          left.cached_tokens + right.cached_tokens)
end

mutable struct Request
    messages::Vector{Message}
    tools::Vector{ToolSpec}
    tool_choice::Union{Nothing,String}
    response_format::Union{Nothing,Dict{String,Any}}
    temperature::Float64
end

Request(messages::Vector{Message}=Message[]) =
    Request(messages, ToolSpec[], nothing, nothing, 0.0)

struct Response
    message::Message
    usage::Usage
    finish_reason::Union{Nothing,String}
end

Response(message::Message) = Response(message, Usage(), nothing)

mutable struct Session
    id::String
    tenant_id::String
    workspace_id::String
    messages::Vector{Message}
end

Session(id::String) = Session(id, "default", "", Message[])

mutable struct RunResult
    run_id::String
    output::String
    steps::Int
    usage::Usage
end

mutable struct MemoryRecord
    id::String
    frame::String
    content::String
    metadata::Union{Nothing,Dict{String,Any}}
    created_at::Union{Nothing,String}
end

MemoryRecord(; id::String="", frame::String="", content::String="",
             metadata=nothing, created_at=nothing) =
    MemoryRecord(id, frame, content, metadata, created_at)

struct PathGrant
    root::String
    access::String
end

struct Action
    kind::String
    session_id::String
    tool_name::Union{Nothing,String}
    arguments::Union{Nothing,Dict{String,Any}}
end

Action(kind::String, session_id::String) = Action(kind, session_id, nothing, nothing)

struct Decision
    allowed::Bool
    reason::String
end



mutable struct Event
    type::String
    session_id::String
    run_id::Union{Nothing,String}
    data::Union{Nothing,Dict{String,Any}}
    at::Union{Nothing,String}
end

Event(type::String, session_id::String) =
    Event(type, session_id, nothing, nothing, string(round(Int, time())))

abstract type AbstractModel end
generate(::AbstractModel, ::Request) = error("model does not implement generate")

end
