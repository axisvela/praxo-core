module AgentRuntime

using ..Json
using ..Models
import ..Models: generate
using ..Errors
using ..Runtime
using ..Middleware

export AbstractModel, generate, StaticModel
export AbstractTool, FuncTool, ToolRegistry
export AbstractPolicy, authorize
export AgentOptions, Agent, run, toolspecs, RunState

struct StaticModel <: AbstractModel
    content::String
end

generate(model::StaticModel, ::Request) = Response(message_assistant(model.content))

abstract type AbstractTool end
tool_name(::AbstractTool) = ""
tool_description(::AbstractTool) = ""
invoke(::AbstractTool, ::Dict{String,Any}) = error("tool does not implement invoke")

struct FuncTool <: AbstractTool
    name::String
    description::String
    func::Function
end

tool_name(tool::FuncTool) = tool.name
tool_description(tool::FuncTool) = tool.description
invoke(tool::FuncTool, arguments::Dict{String,Any}) = tool.func(arguments)

mutable struct ToolRegistry
    tools::Dict{String,AbstractTool}
end

ToolRegistry() = ToolRegistry(Dict{String,AbstractTool}())

register!(registry::ToolRegistry, tool::AbstractTool) = (registry.tools[tool_name(tool)] = tool)
get(registry::ToolRegistry, name::String) =
    haskey(registry.tools, name) ? registry.tools[name] :
    throw(PraxoError("TOOL_NOT_FOUND", "tool not found: $(name)"))

function specs(registry::ToolRegistry)
    specs_list = [ToolSpec(tool_name(tool), tool_description(tool)) for tool in Base.values(registry.tools)]
    sort!(specs_list, by = tool -> tool.name)
    specs_list
end

abstract type AbstractPolicy end
authorize(::AbstractPolicy, ::Action) = Decision(true, "")

mutable struct AgentOptions
    model::AbstractModel
    tools::Union{Nothing,ToolRegistry}
    events::Union{Nothing,AbstractSink}
    policy::Union{Nothing,AbstractPolicy}
    system_prompt::String
    context::Union{Nothing,ContextBudget}
    middleware::Vector{AbstractMiddleware}
    model_middleware::Vector{Function}
    structured_output::Union{Nothing,StructuredOutput}
    allowed_tools::Vector{String}
    tool_selector::Union{Nothing,ToolSelector}
    pii_redactor::Union{Nothing,PiiRedactor}
    model_call_limit::Int
    tool_call_limit::Int
    fallback_model::Union{Nothing,AbstractModel}
    tool_choice::Union{Nothing,String}
    response_format::Union{Nothing,Dict{String,Any}}
    max_steps::Int
    max_tokens::Int
end

function AgentOptions(model::AbstractModel)
    AgentOptions(model, nothing, nothing, nothing, "", nothing,
        AbstractMiddleware[], Function[], nothing, String[], nothing, nothing,
        0, 0, nothing, nothing, nothing, 8, 0)
end

mutable struct Agent
    options::AgentOptions
    system_prompt::String
    middleware::Vector{AbstractMiddleware}
    model_middleware::Vector{Function}
end

function Agent(options::AgentOptions)
    middleware = AbstractMiddleware[]
    append!(middleware, options.middleware)
    options.structured_output === nothing || push!(middleware, options.structured_output)
    options.tool_selector === nothing || push!(middleware, ToolSelectionMiddleware(options.tool_selector))
    options.pii_redactor === nothing || push!(middleware, PiiMiddleware(options.pii_redactor))
    (options.model_call_limit > 0 || options.tool_call_limit > 0) &&
        push!(middleware, CallLimitMiddleware(options.model_call_limit, options.tool_call_limit))
    merged = merge_middleware(middleware)
    model_middleware = copy(options.model_middleware)
    options.fallback_model === nothing || push!(model_middleware, fallback_model(options.fallback_model))
    Agent(options, options.system_prompt, merged, model_middleware)
end

function run(agent::Agent, session::Session, prompt::String)
    max_steps = agent.options.max_steps > 0 ? agent.options.max_steps : 8
    run_id = "run-$(round(Int, time() * 1000))"
    messages = copy(session.messages)
    isempty(agent.system_prompt) || pushfirst!(messages, Message(Roles.SYSTEM, agent.system_prompt))
    push!(messages, Message(Roles.USER, prompt))
    usage = Usage()

    before_run!(agent, RunState(run_id, prompt))
    emit_event(agent, "run.started", session.id, run_id, nothing)
    after_run_invoked = false
    try
        for step in 1:max_steps
            authorize(agent, Action("model.generate", session.id))
            messages = compact(agent, messages)
            request = Request(messages, toolspecs(agent), agent.options.tool_choice,
                              agent.options.response_format, 0.0)
            call = ModelCall(run_id, session.id, request)
            before_model!(agent, call)
            response = if call.skip
                call.response === nothing && throw(PraxoError("AGENT_MIDDLEWARE", "agent: skipped without response"))
                call.response
            else
                generate_chain(agent, call.request)
            end
            after_model!(agent, call, response)
            usage = plus(usage, response.usage)
            if agent.options.max_tokens > 0 &&
               usage.input_tokens + usage.output_tokens > agent.options.max_tokens
                throw(PraxoError("AGENT_MAX_TOKENS", "agent: token budget exceeded"))
            end
            push!(messages, response.message)
            if isempty(response.message.tool_calls)
                result = RunResult(run_id, something(response.message.content, ""), step, usage)
                after_run_invoked = true
                after_run!(agent, result, nothing)
                emit_event(agent, "run.completed", session.id, run_id, nothing)
                return result
            end
            for tool_call in response.message.tool_calls
                push!(messages, invoke_tool(agent, tool_call, run_id, session.id))
            end
        end
        throw(PraxoError("AGENT_MAX_STEPS", "agent: maximum steps exceeded"))
    catch error
        after_run_invoked || after_run!(agent, nothing, error)
        emit_event(agent, "run.failed", session.id, run_id,
                   Dict{String,Any}("error" => sprint(showerror, error)))
        rethrow()
    end
end

function compact(agent::Agent, messages::Vector{Message})
    budget = agent.options.context
    budget === nothing && return messages
    budget.max_tokens == 0 && return messages
    output, ok = compact(budget, messages)
    ok || throw(PraxoError("AGENT_CONTEXT_BUDGET", "agent: context budget cannot fit"))
    output
end

function toolspecs(agent::Agent)
    agent.options.tools === nothing && return ToolSpec[]
    values = specs(agent.options.tools)
    isempty(agent.options.allowed_tools) ? values :
        [tool for tool in values if tool.name in agent.options.allowed_tools]
end

function generate_chain(agent::Agent, request::Request)
    handler = req -> generate(agent.options.model, req)
    for middleware in reverse(agent.model_middleware)
        handler = middleware(handler)
    end
    handler(request)
end

function invoke_tool(agent::Agent, call::ToolCall, run_id::String, session_id::String)
    (isempty(agent.options.allowed_tools) || call.name in agent.options.allowed_tools) ||
        throw(PraxoError("AGENT_TOOL_NOT_ALLOWED", "agent: tool $(call.name) is not allowed"))
    authorize(agent, Action("tool.invoke", session_id, call.name, call.arguments))
    agent.options.tools === nothing &&
        throw(PraxoError("TOOL_NOT_FOUND", "tool $(call.name) is not registered"))
    tool = get(agent.options.tools, call.name)
    context = ToolCallContext(run_id, session_id, call)
    before_tool!(agent, context)
    if context.skip
        value = context.result
        error = context.error
    else
        emit_event(agent, "tool.call", session_id, run_id,
                   Dict{String,Any}("name" => call.name, "arguments" => call.arguments))
        try
            value = invoke(tool, call.arguments)
            error = nothing
        catch exception
            value = nothing
            error = exception isa PraxoError ? exception :
                PraxoError("TOOL_ERROR", sprint(showerror, exception))
        end
    end
    result = ToolResult(value, error)
    after_tool!(agent, context, result)
    result.error !== nothing && throw(result.error)
    Message(Roles.TOOL, Json.stringify(result.value), ContentBlock[], ToolCall[], call.id)
end

function before_run!(agent::Agent, state)
    for middleware in agent.middleware
        before_run!(middleware, state)
    end
end

function before_model!(agent::Agent, call::ModelCall)
    for middleware in agent.middleware
        before_model!(middleware, call)
        call.skip && break
    end
end

function after_model!(agent::Agent, call::ModelCall, response::Response)
    for middleware in agent.middleware
        after_model!(middleware, call, response)
    end
end

function before_tool!(agent::Agent, call::ToolCallContext)
    for middleware in agent.middleware
        before_tool!(middleware, call)
        call.skip && break
    end
end

function after_tool!(agent::Agent, call::ToolCallContext, result::ToolResult)
    for middleware in agent.middleware
        after_tool!(middleware, call, result)
    end
end

function after_run!(agent::Agent, result, error)
    for middleware in agent.middleware
        after_run!(middleware, result, error)
    end
end

function authorize(agent::Agent, action::Action)
    agent.options.policy === nothing && return
    decision = authorize(agent.options.policy, action)
    decision.allowed || throw(PraxoError("AGENT_POLICY_DENIED",
        "agent: $(action.kind) denied: $(decision.reason)"))
end

function emit_event(agent::Agent, type::String, session_id::String, run_id::String, data)
    agent.options.events === nothing && return
    emit(agent.options.events, Event(type, session_id, run_id, data, nothing))
end

function merge_middleware(items::Vector{AbstractMiddleware})
    output = AbstractMiddleware[]
    positions = Dict{String,Int}()
    for item in items
        name = middleware_name(item)
        if isempty(name)
            push!(output, item)
        elseif haskey(positions, name)
            output[positions[name]] = item
        else
            positions[name] = length(output) + 1
            push!(output, item)
        end
    end
    output
end

struct RunState
    run_id::String
    prompt::String
end

end
