using PraxoCore
import PraxoCore
const RT = PraxoCore.Runtime
const MW = PraxoCore.Middleware
const AR = PraxoCore.AgentRuntime

mutable struct RecordingSink <: AbstractSink
    types::Vector{String}
end

RecordingSink() = RecordingSink(String[])
RT.emit(sink::RecordingSink, event::Event) = push!(sink.types, event.type)

mutable struct ScriptedModel <: AbstractModel
    steps::Vector{Any}
    next::Int
end

ScriptedModel(steps) = ScriptedModel(collect(steps), 1)

function AR.generate(model::ScriptedModel, request::Request)
    model.next > length(model.steps) && error("script exhausted")
    step = model.steps[model.next]
    model.next += 1
    calls = ToolCall[]
    for item in Json.getarray(step, "toolCalls")
        input = Json.getvalue(item, "arguments", Dict{String,Any}())
        push!(calls, ToolCall(
            Json.getstring(item, "id", ""),
            Json.getstring(item, "name", ""),
            input isa AbstractDict ? Dict{String,Any}(String(k) => v for (k, v) in input) : Dict{String,Any}(),
        ))
    end
    Response(
        Message(Roles.ASSISTANT, Json.getstring(step, "content", ""),
                ContentBlock[], calls, nothing),
        Usage(Json.getint(step, "inputTokens", 0), Json.getint(step, "outputTokens", 0), 0),
        nothing,
    )
end

struct FixedSelector <: ToolSelector
    names::Vector{String}
end

MW.select(selector::FixedSelector, query::String, tools::Vector{ToolSpec}) = selector.names
function error_code(error)
    error isa PraxoError ? error.code : ""
end

function run_memory(input, expect)
    store = MemoryStore()
    for put in Json.getarray(input, "puts")
        record = Json.getvalue(put, "record", Dict{String,Any}())
        RT.put!(store, Json.getstring(put, "session", ""), MemoryRecord(
            id = Json.getstring(record, "id", ""),
            frame = Json.getstring(record, "frame", ""),
            content = Json.getstring(record, "content", ""),
            created_at = Json.getstring(record, "createdAt", nothing),
        ))
    end
    records = RT.search(store, Json.getstring(input, "session", ""),
                     Json.getstring(input, "query", ""), Json.getint(input, "limit", 0))
    ids = [record.id for record in records]
    contents = [record.content for record in records]
    check(Json.equals(isempty(ids) ? nothing : ids, Json.getvalue(expect, "ids", nothing)), "ids mismatch")
    check(Json.equals(isempty(contents) ? nothing : contents, Json.getvalue(expect, "contents", nothing)), "contents mismatch")
end

function run_event(input, expect)
    events = [Event(String(event), "s1") for event in Json.getarray(input, "events")]
    if Json.getstring(input, "sink", "") == "multi"
        count = max(1, Json.getint(input, "sinkCount", 1))
        sinks = [RecordingSink() for _ in 1:count]
        multi = MultiSink(AbstractSink[sinks...])
        for event in events
            emit(multi, event)
        end
        per_sink = [sink.types for sink in sinks]
        check(Json.equals(per_sink, Json.getarray(expect, "perSink")), "perSink mismatch")
        return
    end
    predicate_types = Json.getarray(input, "predicateTypes")
    allowed = isempty(predicate_types) && Json.getvalue(input, "predicateTypes", nothing) === nothing ? nothing :
        Set(String[item for item in predicate_types if item isa AbstractString])
    sink = RecordingSink()
    filter = FilterSink(sink, event -> allowed === nothing || event.type in allowed)
    for event in events
        emit(filter, event)
    end
    check(Json.equals(isempty(sink.types) ? nothing : sink.types, Json.getvalue(expect, "delivered", nothing)), "delivered mismatch")
end

function run_stream(expect)
    check(StreamKinds == Json.getarray(expect, "kinds"), "kinds mismatch")
end

function run_checkpoint(input, expect)
    allow = CheckpointAllowlist()
    for type in Json.getarray(input, "registered")
        RT.register!(allow, String(type))
    end
    operation = Json.getstring(input, "operation", "roundtrip")
    type = Json.getstring(input, "type", "")
    value = Json.getvalue(input, "value", nothing)
    if operation == "roundtrip"
        data = RT.marshal(allow, type, value)
        check(Json.equals(RT.unmarshal(allow, data), Json.getvalue(expect, "value", nothing)), "value mismatch")
        return
    end
    code = ""
    try
        if operation == "marshal"
            RT.marshal(allow, type, value)
        elseif operation == "unmarshal"
            RT.unmarshal(allow, Json.stringify(Dict{String,Any}("type" => type, "data" => value)))
        else
            error("unknown checkpoint operation")
        end
    catch error
        code = error_code(error)
    end
    check(code == Json.getstring(expect, "errorCode", ""), "errorCode: got $(code)")
end

function run_policy(input, expect)
    mktempdir() do root
        for dir in Json.getarray(input, "makeDirs")
            mkpath(joinpath(root, String(dir)))
        end
        grants = PathGrant[]
        for item in Json.getarray(input, "grants")
            grant_root = joinpath(root, Json.getstring(item, "root", ""))
            mkpath(grant_root)
            push!(grants, PathGrant(grant_root, Json.getstring(item, "access", "read")))
        end
        checker = PathChecker(grants)
        target = joinpath(root, Json.getstring(input, "target", ""))
        need = Json.getstring(input, "need", "read")
        if Json.getbool(expect, "error", false)
            caught = false
            try
                PraxoCore.check(checker, target, need)
            catch
                caught = true
            end
            check(caught, "expected a policy error")
            return
        end
        result = PraxoCore.check(checker, target, need).allowed
        check(result == Json.getbool(expect, "allowed", false), "allowed: got $(result)")
    end
end

function run_context(input, expect)
    messages = Message[]
    for item in Json.getarray(input, "messages")
        push!(messages, Message(Json.getstring(item, "role", ""), Json.getstring(item, "content", nothing)))
    end
    if Json.getstring(input, "operation", "") == "estimate"
        tokens = RT.estimate_tokens(messages)
        check(tokens == Json.getint(expect, "tokens", 0), "tokens: got $(tokens)")
        return
    end
    budget = ContextBudget(Json.getint(Json.getvalue(input, "budget", Dict()), "maxTokens", 0),
                           Json.getint(Json.getvalue(input, "budget", Dict()), "keepRecent", 0))
    output, ok = RT.compact(budget, messages)
    check(ok == Json.getbool(expect, "ok", false), "ok: got $(ok)")
    ok || return
    tokens = RT.estimate_tokens(output)
    check(tokens == Json.getint(expect, "tokens", 0), "tokens: got $(tokens)")
    wire = [message_dict(message) for message in output]
    check(Json.equals(wire, Json.getarray(expect, "messages")), "messages mismatch")
end

function run_middleware(input, expect)
    operation = Json.getstring(input, "operation", "")
    if operation == "pii"
        got = MW.redact(PiiRedactor(), Json.getstring(input, "text", ""))
        check(got == Json.getstring(expect, "text", ""), "text: got $(got)")
    elseif operation == "pii-value"
        middleware = PiiMiddleware(PiiRedactor())
        result = ToolResult(Json.getvalue(input, "value", nothing))
        MW.after_tool!(middleware, ToolCallContext("r1", "s1", ToolCall("c", "echo", Dict{String,Any}())), result)
        check(Json.equals(result.value, Json.getvalue(expect, "value", nothing)), "value mismatch")
    elseif operation == "structured"
        output = StructuredOutput(Json.getvalue(input, "schema", Dict{String,Any}());
            max_repairs = Json.getint(input, "maxRepairs", 0))
        repair = Json.getstring(input, "repairOutput", nothing)
        repair !== nothing && (output.repairer = (text, error) -> repair)
        result = RunResult("r1", Json.getstring(input, "output", ""), 0, Usage())
        code = ""
        try
            MW.apply!(output, result)
        catch error
            code = error_code(error)
        end
        if Json.getbool(expect, "ok", false)
            check(code == "", "expected success")
            check(result.output == Json.getstring(expect, "output", ""), "output mismatch")
        else
            check(code == Json.getstring(expect, "errorCode", ""), "errorCode: got $(code)")
        end
    elseif operation == "call-limit"
        middleware = CallLimitMiddleware(Json.getint(input, "modelLimit", 0), Json.getint(input, "toolLimit", 0))
        MW.before_run!(middleware, AR.RunState("r1", ""))
        outcomes = String[]
        for kind in Json.getarray(input, "calls")
            code = ""
            try
                kind == "model" ? MW.before_model!(middleware, ModelCall("r1", "s1", Request())) :
                    MW.before_tool!(middleware, ToolCallContext("r1", "s1", ToolCall("c", "echo", Dict{String,Any}())))
            catch error
                code = error_code(error)
            end
            push!(outcomes, isempty(code) ? "ok" : code)
        end
        check(Json.equals(outcomes, Json.getarray(expect, "outcomes")), "outcomes mismatch")
    elseif operation == "tool-selection"
        selected = String[item for item in Json.getarray(input, "selected") if item isa AbstractString]
        middleware = ToolSelectionMiddleware(FixedSelector(selected))
        tools = [ToolSpec(String(item)) for item in Json.getarray(input, "tools")]
        call = ModelCall("r1", "s1", Request(Message[], tools, nothing, nothing, 0.0))
        MW.before_model!(middleware, call)
        advertised = [tool.name for tool in call.request.tools]
        check(Json.equals(advertised, Json.getarray(expect, "advertised")), "advertised mismatch")
        code = ""
        try
            MW.before_tool!(middleware, ToolCallContext("r1", "s1",
                ToolCall("c", Json.getstring(input, "requested", ""), Dict{String,Any}())))
        catch error
            code = error_code(error)
        end
        code == "" && (code = "ok")
        check(code == Json.getstring(expect, "reject", ""), "reject: got $(code)")
    elseif operation == "fallback"
        content = Json.getstring(input, "fallbackContent", "")
        handler = MW.fallback_model(StaticModel(content))(request -> error("primary failed"))
        response = handler(Request())
        check(response.message.content == content, "output mismatch")
    end
end

function run_agent_loop(input, expect)
    invocations = Ref(0)
    registry = ToolRegistry()
    for tool in Json.getarray(input, "tools")
        AR.register!(registry, FuncTool(Json.getstring(tool, "name", ""),
            Json.getstring(tool, "description", ""), args -> (invocations[] += 1; args)))
    end
    sink = RecordingSink()
    options = AgentOptions(ScriptedModel(Json.getarray(input, "script")))
    options.tools = registry
    options.events = sink
    options.max_steps = Json.getint(input, "maxSteps", 0)
    options.max_tokens = Json.getint(input, "maxTokens", 0)
    agent = Agent(options)
    result = nothing
    failure = nothing
    try
        result = run_agent(agent, Session("s1"), Json.getstring(input, "prompt", ""))
    catch error
        failure = error
    end
    if Json.getbool(expect, "error", false)
        check(failure !== nothing, "unexpected success")
        code = Json.getstring(expect, "errorCode", nothing)
        code === nothing || check(error_code(failure) == code, "errorCode: got $(error_code(failure))")
    else
        check(failure === nothing, sprint(showerror, failure))
        check(result.output == Json.getstring(expect, "output", ""), "output mismatch")
        check(result.steps == Json.getint(expect, "steps", 0), "steps: got $(result.steps)")
    end
    check(invocations[] == Json.getint(expect, "toolInvocations", 0), "tool invocations mismatch")
    check(Json.equals(isempty(sink.types) ? nothing : sink.types, Json.getvalue(expect, "events", nothing)), "events mismatch")
end
