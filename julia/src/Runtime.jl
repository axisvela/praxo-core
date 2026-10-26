module Runtime

using ..Json
using ..Models
using ..Errors

export AbstractSink, MultiSink, FilterSink, emit
export MemoryStore, put!, search
export CheckpointAllowlist, register!, marshal, unmarshal
export PathChecker, check, allowed
export ContextEstimator, ContextBudget, estimate_tokens, truncate_to_tokens, compact

abstract type AbstractSink end

function emit(::AbstractSink, ::Event)
    error("sink does not implement emit")
end

struct MultiSink <: AbstractSink
    sinks::Vector{AbstractSink}
end

function emit(sink::MultiSink, event::Event)
    for child in sink.sinks
        emit(child, event)
    end
end

struct FilterSink <: AbstractSink
    sink::AbstractSink
    predicate::Function
end

function emit(sink::FilterSink, event::Event)
    sink.predicate(event) && emit(sink.sink, event)
end

mutable struct MemoryStore
    records::Dict{String,Vector{MemoryRecord}}
    sequence::Int
end

MemoryStore() = MemoryStore(Dict{String,Vector{MemoryRecord}}(), 0)

function put!(store::MemoryStore, session_id::String, record::MemoryRecord)
    if isempty(record.id)
        record.id = "mem-$(round(Int, time() * 1000))-$(store.sequence)"
        store.sequence += 1
    end
    record.created_at === nothing && (record.created_at = string(round(Int, time())))
    push!(get!(store.records, session_id, MemoryRecord[]), record)
    record
end

function search(store::MemoryStore, session_id::String, query::String, limit::Int)
    records = get(store.records, session_id, MemoryRecord[])
    needle = lowercase(strip(query))
    matches = filter(records) do record
        isempty(needle) || occursin(needle, lowercase(record.content))
    end
    sort!(matches, by = record -> something(record.created_at, ""), rev = true)
    limit > 0 ? matches[1:min(limit, length(matches))] : matches
end

mutable struct CheckpointAllowlist
    registered::Set{String}
end

CheckpointAllowlist() = CheckpointAllowlist(Set{String}())

function register!(allow::CheckpointAllowlist, type::String)
    isempty(type) && throw(PraxoError("CHECKPOINT_ERROR", "checkpoint: type is required"))
    push!(allow.registered, type)
end

function marshal(allow::CheckpointAllowlist, type::String, value)
    type in allow.registered ||
        throw(PraxoError("CHECKPOINT_TYPE_NOT_ALLOWED", "checkpoint: payload type not allowed: $(type)"))
    Json.stringify(Dict{String,Any}("type" => type, "data" => value))
end

function unmarshal(allow::CheckpointAllowlist, data::String)
    envelope = Json.parse_json(data)
    envelope isa AbstractDict ||
        throw(PraxoError("CHECKPOINT_ERROR", "checkpoint: envelope must be an object"))
    type = Json.getstring(envelope, "type", "")
    type in allow.registered ||
        throw(PraxoError("CHECKPOINT_TYPE_NOT_ALLOWED", "checkpoint: payload type not allowed: $(type)"))
    Json.getvalue(envelope, "data", nothing)
end

struct PathChecker
    grants::Vector{PathGrant}
end

function check(checker::PathChecker, target::String, need::String)
    need in ("read", "write", "readwrite") ||
        error("policy: invalid requested access $(need)")
    isempty(checker.grants) && return Decision(false, "no allowed roots")
    resolved = resolve_path(target)
    matched = nothing
    for grant in checker.grants
        within(grant.root, resolved) || continue
        matched = grant.root
        allows(grant.access, need) && return Decision(true, "path within $(grant.root)")
    end
    matched === nothing ? Decision(false, "path outside allowed roots") :
        Decision(false, "path within $(matched) but the grant is insufficient")
end

allowed(checker::PathChecker, target::String, need::String) = check(checker, target, need).allowed

function resolve_path(value::String)
    try
        return realpath(value)
    catch
    end
    parent = dirname(value)
    parent == value && return value
    return joinpath(resolve_path(parent), basename(value))
end

function within(root::String, target::String)
    normalize = Sys.iswindows() ? lowercase : identity
    root_value = normalize(rstrip(root, ['/', '\\']))
    target_value = normalize(rstrip(target, ['/', '\\']))
    root_value == target_value && return true
    separator = Sys.iswindows() ? "\\" : "/"
    startswith(target_value, root_value * separator)
end

allows(grant::String, need::String) =
    need == "read" ? grant in ("read", "readwrite") :
    need == "write" ? grant in ("write", "readwrite") :
    grant == "readwrite"

module ContextEstimator
using ..Models
export estimate_tokens, truncate_to_tokens
const COMPACT_MARKER_PREFIX = "[context compacted:"

function estimate_tokens(messages::Vector{Message})
    total = 0
    for message in messages
        total += 4 + div(length(something(message.content, "")), 4) +
            div(length(something(message.tool_id, "")), 4)
        for block in message.content_blocks
            total += 4 + div(length(something(block.text, "")), 4) +
                div(length(something(block.image_url, "")), 4) +
                div(length(something(block.data, "")), 4)
        end
        for call in message.tool_calls
            total += 4 + div(length(call.name), 4) +
                div(length(Json.stringify(call.arguments)), 4)
        end
    end
    total
end

function truncate_to_tokens(value::String, tokens::Int)
    tokens <= 0 && return ""
    limit = tokens * 4
    length(value) <= limit && return value
    limit <= 16 ? value[1:limit] : value[1:limit-16] * "\n[truncated]"
end
end

estimate_tokens(messages::Vector{Message}) = ContextEstimator.estimate_tokens(messages)
truncate_to_tokens(value::String, tokens::Int) = ContextEstimator.truncate_to_tokens(value, tokens)

struct ContextBudget
    max_tokens::Int
    keep_recent::Int
end

function compact(budget::ContextBudget, messages::Vector{Message})
    if budget.max_tokens == 0 || estimate_tokens(messages) <= budget.max_tokens
        return (messages, true)
    end
    system = Message[]
    rest = Message[]
    for message in messages
        if message.role == Roles.SYSTEM
            startswith(something(message.content, ""), ContextEstimator.COMPACT_MARKER_PREFIX) && continue
            push!(system, message)
        else
            push!(rest, message)
        end
    end
    if estimate_tokens(system) > budget.max_tokens
        isempty(system) && return (Message[], false)
        first = system[1]
        truncated = Message(first.role, truncate_to_tokens(something(first.content, ""),
            max(0, budget.max_tokens - 4)), first.content_blocks, first.tool_calls, first.tool_id)
        system = Message[truncated]
        estimate_tokens(system) > budget.max_tokens && return (Message[], false)
    end
    keep = budget.keep_recent > 0 ? budget.keep_recent : 4
    start = max(0, length(rest) - keep)
    while start > 0 && rest[start + 1].role == Roles.TOOL
        start -= 1
    end
    marker = Message(Roles.SYSTEM, "$(ContextEstimator.COMPACT_MARKER_PREFIX) $(start) older messages omitted]")
    kept = start >= length(rest) ? Message[] : rest[start+1:end]
    output = build(system, marker, start > 0, kept)
    while estimate_tokens(output) > budget.max_tokens && length(kept) > 1
        kept[2].role == Roles.TOOL && break
        popfirst!(kept)
        output = build(system, marker, start > 0, kept)
    end
    return (output, estimate_tokens(output) <= budget.max_tokens)
end

function build(system::Vector{Message}, marker::Message, include_marker::Bool, kept::Vector{Message})
    output = copy(system)
    include_marker && push!(output, marker)
    append!(output, kept)
    return output
end

function compact(budget::ContextBudget, messages)
    compact(budget, convert(Vector{Message}, messages))
end

end
