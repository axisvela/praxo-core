push!(LOAD_PATH, normpath(joinpath(@__DIR__, "..", "..", "src")))
using PraxoCore

struct Checkpoint
    id::String
    session_id::String
    run_id::String
    status::String
    messages::Vector{Message}
end

const Store = Dict{String,String}

function save_checkpoint!(store::Store, allow::CheckpointAllowlist, checkpoint::Checkpoint)
    payload = Dict{String,Any}(
        "id" => checkpoint.id,
        "sessionId" => checkpoint.session_id,
        "runId" => checkpoint.run_id,
        "status" => checkpoint.status,
        "messages" => [PraxoCore.Models.message_dict(message) for message in checkpoint.messages],
    )
    store[checkpoint.session_id] = marshal(allow, "session", payload)
    checkpoint
end

function message_from_dict(value)
    blocks = ContentBlock[
        ContentBlock(
            Json.getstring(block, "type", "text"),
            Json.getvalue(block, "text", nothing),
            Json.getvalue(block, "image_url", nothing),
            Json.getvalue(block, "data", nothing),
        )
        for block in Json.getarray(value, "contentBlocks")
    ]
    calls = ToolCall[
        ToolCall(
            Json.getstring(call, "id", ""),
            Json.getstring(call, "name", ""),
            call["arguments"],
        )
        for call in Json.getarray(value, "toolCalls")
    ]
    Message(
        Json.getstring(value, "role", ""),
        Json.getvalue(value, "content", nothing),
        blocks,
        calls,
        Json.getvalue(value, "toolId", nothing),
    )
end

function load_checkpoint(store::Store, allow::CheckpointAllowlist, session_id::String)
    haskey(store, session_id) || return nothing
    payload = unmarshal(allow, store[session_id])
    Checkpoint(
        Json.getstring(payload, "id", ""),
        Json.getstring(payload, "sessionId", ""),
        Json.getstring(payload, "runId", ""),
        Json.getstring(payload, "status", ""),
        Message[message_from_dict(message) for message in Json.getarray(payload, "messages")],
    )
end

struct TurnModel <: AbstractModel end

PraxoCore.generate(::TurnModel, request::Request) =
    Response(PraxoCore.Models.message_assistant("turn $(length(request.messages))"))

function main()
    allow = CheckpointAllowlist()
    register!(allow, "session")
    store = Store()
    session = Session("session-1")
    session.messages = Message[
        Message(Roles.USER, "first"),
        Message(Roles.ASSISTANT, "ack"),
    ]
    save_checkpoint!(
        store,
        allow,
        Checkpoint("cp-1", session.id, "run-1", "completed", session.messages),
    )

    options = AgentOptions(TurnModel())
    options.max_steps = 2
    agent = Agent(options)

    loaded = load_checkpoint(store, allow, session.id)
    loaded === nothing && error("checkpoint not found")
    session.messages = loaded.messages
    result = run_agent(agent, session, "second")
    @assert result.output == "turn 3"

    push!(session.messages, Message(Roles.USER, "second"))
    push!(session.messages, Message(Roles.ASSISTANT, result.output))
    save_checkpoint!(
        store,
        allow,
        Checkpoint("cp-2", session.id, "run-2", "completed", session.messages),
    )

    loaded = load_checkpoint(store, allow, session.id)
    loaded === nothing && error("checkpoint not found")
    session.messages = loaded.messages
    result = run_agent(agent, session, "third")
    @assert result.output == "turn 5"

    println("restored messages: $(length(loaded.messages))")
    println("output: $(result.output)")
end

main()
