module Middleware

using ..Json
using ..Models
using ..JsonSchema
using ..Errors

export ModelCall, ToolCallContext, ToolResult, AbstractMiddleware
export before_run!, before_model!, after_model!, before_tool!, after_tool!, after_run!
export PiiRule, PiiRedactor, PiiMiddleware
export StructuredOutput, CallLimitMiddleware
export ToolSelector, ToolSelectionMiddleware, fallback_model, select
export redact, redact_value, apply!, before_run!, before_model!, after_model!
export before_tool!, after_tool!, after_run!

mutable struct ModelCall
    run_id::String
    session_id::String
    request::Request
    skip::Bool
    response::Union{Nothing,Response}
end

ModelCall(run_id::String, session_id::String, request::Request) =
    ModelCall(run_id, session_id, request, false, nothing)

mutable struct ToolCallContext
    run_id::String
    session_id::String
    call::ToolCall
    skip::Bool
    result::Any
    error::Union{Nothing,PraxoError}
end

ToolCallContext(run_id::String, session_id::String, call::ToolCall) =
    ToolCallContext(run_id, session_id, call, false, nothing, nothing)

mutable struct ToolResult
    value::Any
    error::Union{Nothing,PraxoError}
end

ToolResult(value) = ToolResult(value, nothing)

abstract type AbstractMiddleware end

middleware_name(::AbstractMiddleware) = ""
before_run!(::AbstractMiddleware, state) = nothing
before_model!(::AbstractMiddleware, call::ModelCall) = nothing
after_model!(::AbstractMiddleware, call::ModelCall, response::Response) = nothing
before_tool!(::AbstractMiddleware, call::ToolCallContext) = nothing
after_tool!(::AbstractMiddleware, call::ToolCallContext, result::ToolResult) = nothing
after_run!(::AbstractMiddleware, result, error) = nothing

struct PiiRule
    name::String
    pattern::Regex
    replacement::String
end

struct PiiRedactor
    rules::Vector{PiiRule}
end

function PiiRedactor()
    PiiRedactor([
        PiiRule("email", r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}", "[REDACTED:email]"),
        PiiRule("ssn", r"\b\d{3}-\d{2}-\d{4}\b", "[REDACTED:ssn]"),
        PiiRule("credit_card", r"\b(?:\d{4}[ -]?){3}\d{4}\b", "[REDACTED:credit_card]"),
        PiiRule("phone", r"\b(?:\+?1[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}\b", "[REDACTED:phone]"),
    ])
end

function redact(redactor::PiiRedactor, text::String)
    output = text
    for rule in redactor.rules
        output = replace(output, rule.pattern => rule.replacement)
    end
    output
end

function redact_value(redactor::PiiRedactor, value)
    value isa AbstractString && return redact(redactor, String(value))
    if value isa AbstractDict
        return Dict{String,Any}(String(key) => redact_value(redactor, item) for (key, item) in value)
    end
    value isa AbstractVector && return [redact_value(redactor, item) for item in value]
    value
end

struct PiiMiddleware <: AbstractMiddleware
    redactor::PiiRedactor
end

middleware_name(::PiiMiddleware) = "pii"

function before_model!(middleware::PiiMiddleware, call::ModelCall)
    messages = Message[]
    for message in call.request.messages
        blocks = [ContentBlock(block.type, redact(middleware.redactor, something(block.text, "")),
                               block.image_url, block.data) for block in message.content_blocks]
        push!(messages, Message(message.role, redact(middleware.redactor, something(message.content, "")),
                                blocks, message.tool_calls, message.tool_id))
    end
    call.request = Request(messages, call.request.tools, call.request.tool_choice,
                           call.request.response_format, call.request.temperature)
end

function after_tool!(middleware::PiiMiddleware, call::ToolCallContext, result::ToolResult)
    result.value = redact_value(middleware.redactor, result.value)
end

mutable struct StructuredOutput <: AbstractMiddleware
    schema::Dict{String,Any}
    output_name::String
    strategy::String
    max_repairs::Int
    repairer::Union{Nothing,Function}
end

StructuredOutput(schema::Dict{String,Any}; output_name::String="structured_output",
                 strategy::String="auto", max_repairs::Int=0) =
    StructuredOutput(schema, output_name, strategy, max_repairs, nothing)

middleware_name(::StructuredOutput) = "structured-output"

function validate_output(output::StructuredOutput, text::String)
    data = extract_json(text)
    errors = JsonSchema.validate(output.schema, data)
    isempty(errors) || throw(PraxoError("AGENT_STRUCTURED_OUTPUT", "schema: $(length(errors)) error(s)"))
end

function apply!(output::StructuredOutput, result::RunResult)
    text = result.output
    last_error = nothing
    for attempt in 0:output.max_repairs
        try
            validate_output(output, text)
            result.output = text
            return
        catch error
            last_error = error
        end
        (attempt == output.max_repairs || output.repairer === nothing) && break
        text = output.repairer(text, last_error)
        isempty(strip(text)) &&
            throw(PraxoError("AGENT_STRUCTURED_OUTPUT", "agent: repair returned empty output"))
    end
    throw(PraxoError("AGENT_STRUCTURED_OUTPUT",
        "agent: structured output validation failed: $(last_error === nothing ? "" : last_error.message)"))
end

function before_model!(output::StructuredOutput, call::ModelCall)
    if call.request.response_format === nothing && output.strategy != "tool" && !isempty(output.schema)
        call.request.response_format = Dict{String,Any}("name" => output.output_name, "schema" => output.schema)
    end
    if output.strategy == "tool" && any(tool -> tool.name == output.output_name, call.request.tools)
        call.request.tool_choice = "required"
    end
end

function after_run!(output::StructuredOutput, result, error)
    error === nothing && result !== nothing && apply!(output, result)
end

function extract_json(text::String)
    value = strip(text)
    isempty(value) && throw(PraxoError("AGENT_STRUCTURED_OUTPUT", "empty output"))
    if startswith(value, "```")
        index = findfirst('\n', value)
        index !== nothing && (value = value[nextind(value, index):end])
        value = strip(value, '`')
    end
    start = findfirst(character -> character == '{' || character == '[', value)
    start === nothing && throw(PraxoError("AGENT_STRUCTURED_OUTPUT", "output does not contain JSON"))
    try
        Json.parse_json(value[start:end])
    catch error
        throw(PraxoError("AGENT_STRUCTURED_OUTPUT", "decode JSON: $(error)"))
    end
end

mutable struct CallLimitMiddleware <: AbstractMiddleware
    model_limit::Int
    tool_limit::Int
    counts::Dict{String,Tuple{Int,Int}}
end

CallLimitMiddleware(model_limit::Int, tool_limit::Int) =
    CallLimitMiddleware(model_limit, tool_limit, Dict{String,Tuple{Int,Int}}())

middleware_name(::CallLimitMiddleware) = "call-limit"

function before_run!(middleware::CallLimitMiddleware, state)
    middleware.counts[state.run_id] = (0, 0)
end

function before_model!(middleware::CallLimitMiddleware, call::ModelCall)
    models, tools = get(middleware.counts, call.run_id, (0, 0))
    models += 1
    middleware.counts[call.run_id] = (models, tools)
    middleware.model_limit > 0 && models > middleware.model_limit &&
        throw(PraxoError("AGENT_MODEL_CALL_LIMIT", "agent: model call limit exceeded"))
end

function before_tool!(middleware::CallLimitMiddleware, call::ToolCallContext)
    models, tools = get(middleware.counts, call.run_id, (0, 0))
    tools += 1
    middleware.counts[call.run_id] = (models, tools)
    middleware.tool_limit > 0 && tools > middleware.tool_limit &&
        throw(PraxoError("AGENT_TOOL_CALL_LIMIT", "agent: tool call limit exceeded"))
end

function after_run!(middleware::CallLimitMiddleware, result, error)
    result === nothing || delete!(middleware.counts, result.run_id)
end

abstract type ToolSelector end
select(::ToolSelector, query::String, tools::Vector{ToolSpec}) = String[]

mutable struct ToolSelectionMiddleware <: AbstractMiddleware
    selector::ToolSelector
    selected::Dict{String,Set{String}}
end

ToolSelectionMiddleware(selector::ToolSelector) =
    ToolSelectionMiddleware(selector, Dict{String,Set{String}}())

middleware_name(::ToolSelectionMiddleware) = "tool-selection"

function before_model!(middleware::ToolSelectionMiddleware, call::ModelCall)
    chosen = Set(select(middleware.selector, last_user_message(call.request.messages), call.request.tools))
    middleware.selected[call.run_id] = chosen
    call.request.tools = [tool for tool in call.request.tools if tool.name in chosen]
end

function before_tool!(middleware::ToolSelectionMiddleware, call::ToolCallContext)
    if haskey(middleware.selected, call.run_id) && !(call.call.name in middleware.selected[call.run_id])
        throw(PraxoError("AGENT_TOOL_NOT_SELECTED", "agent: tool is not selected"))
    end
end

function after_run!(middleware::ToolSelectionMiddleware, result, error)
    result === nothing || delete!(middleware.selected, result.run_id)
end

function last_user_message(messages::Vector{Message})
    for message in reverse(messages)
        message.role == Roles.USER && return something(message.content, "")
    end
    ""
end

function fallback_model(fallback)
    return next -> function (request::Request)
        try
            return next(request)
        catch primary
            fallback === nothing && rethrow()
            try
                return generate(fallback, request)
            catch
                throw(primary)
            end
        end
    end
end

end
