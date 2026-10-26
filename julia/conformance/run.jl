using JSON
using PraxoCore

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))


function check(condition::Bool, message::String)
    condition || error(message)
end

include(joinpath(@__DIR__, "core.jl"))

function run_toolcall(input, expect)
    operation = Json.getstring(input, "operation", "")
    content = Json.getstring(input, "content", "")
    if operation == "strip"
        got = ToolCallParser.strip_markup(content)
        check(got == Json.getstring(expect, "text", ""), "strip: got $(got)")
        return
    end
    call = ToolCallParser.parse_toolcall(content)
    if Json.getbool(expect, "nil", false)
        check(call === nothing, "expected nil")
        return
    end
    check(call !== nothing, "expected a tool call")
    check(call.name == Json.getstring(expect, "name", ""), "name: got $(call.name)")
    expected = Json.getvalue(expect, "input", Dict{String,Any}())
    check(Json.equals(call.input, expected), "input mismatch")
end

function run_jsonschema(input, expect)
    errors = JsonSchema.validate(
        Json.getvalue(input, "schema", nothing),
        Json.getvalue(input, "data", nothing),
    )
    paths = sort([error.path for error in errors])
    expected = sort(String[
        item for item in Json.getarray(expect, "errorPaths") if item isa AbstractString
    ])
    check(isempty(errors) == Json.getbool(expect, "valid", false), "valid mismatch")
    check(paths == expected, "errorPaths: got $(paths)")
end

function run_plugin(input, expect)
    raw = Json.getstring(input, "raw", nothing)
    if raw === nothing
        raw = Json.stringify(Json.getvalue(input, "manifest", Dict{String,Any}()))
    end
    manifest = nothing
    try
        manifest = Plugin.parse_manifest(raw)
    catch
    end
    check((manifest !== nothing) == Json.getbool(expect, "valid", false), "valid mismatch")
    manifest === nothing && return
    id = Json.getstring(expect, "id", nothing)
    if id !== nothing
        check(manifest.id == id, "id: got $(manifest.id)")
    end
    kind = Json.getstring(expect, "kind", nothing)
    if kind !== nothing
        check(manifest.kind == kind, "kind: got $(manifest.kind)")
    end
end

function run_vector(group, vector)
    input = Json.getvalue(vector, "input", Dict{String,Any}())
    expect = Json.getvalue(vector, "expect", Dict{String,Any}())
    if group == "toolcall"
        run_toolcall(input, expect)
    elseif group == "jsonschema"
        run_jsonschema(input, expect)
    elseif group == "plugin"
        run_plugin(input, expect)
    elseif group == "memory"
        run_memory(input, expect)
    elseif group == "event"
        run_event(input, expect)
    elseif group == "stream"
        run_stream(expect)
    elseif group == "checkpoint"
        run_checkpoint(input, expect)
    elseif group == "policy"
        run_policy(input, expect)
    elseif group == "context"
        run_context(input, expect)
    elseif group == "middleware"
        run_middleware(input, expect)
    elseif group == "agent-loop"
        run_agent_loop(input, expect)
    end
end

function run_all()
    version = strip(read(joinpath(ROOT, "spec", "SPEC_VERSION"), String))
    failures = String[]
    seen = Dict{String,String}()
    for file in sort(filter(name -> endswith(name, ".json"), readdir(joinpath(ROOT, "spec", "vectors"))))
        name = replace(file, ".json" => "")
        path = joinpath(ROOT, "spec", "vectors", file)
        file_data = try
            JSON.parse(read(path, String))
        catch
            push!(failures, "$(name): invalid vector file")
            continue
        end
        group = get(file_data, "group", "")
        get(file_data, "specVersion", "") == version ||
            push!(failures, "$(name): specVersion mismatch")
        name == group || push!(failures, "$(name): group mismatch")
        for vector in get(file_data, "vectors", Any[])
            id = get(vector, "id", "")
            if haskey(seen, id)
                push!(failures, "$(group)/$(id): duplicate id with $(seen[id])")
            end
            seen[id] = group
            try
                run_vector(group, vector)
            catch error_value
                push!(failures, "$(group)/$(id): $(error_value)")
            end
        end
    end
    return failures
end

failures = run_all()
if isempty(failures)
    println("all spec vectors passed")
    exit(0)
end
for failure in failures
    println(stderr, failure)
end
exit(1)
