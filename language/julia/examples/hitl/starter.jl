push!(LOAD_PATH, normpath(joinpath(@__DIR__, "..", "..", "src")))
using PraxoCore

struct FixtureModel <: AbstractModel end

function PraxoCore.generate(::FixtureModel, request::Request)
    if !isempty(request.messages) && request.messages[end].role == Roles.TOOL
        return Response(PraxoCore.Models.message_assistant("done"))
    end
    Response(PraxoCore.Models.message_assistant("", [
        ToolCall("write-note-1", "write_note", Dict{String,Any}(
            "text" => "hello",
            "visibility" => "public",
        )),
    ]))
end

struct NotePolicy <: AbstractPolicy end

function PraxoCore.authorize(::NotePolicy, action::Action)
    if action.kind == "model.generate"
        return Decision(true, "model generation")
    elseif action.kind == "tool.invoke"
        visibility = action.arguments === nothing ? nothing :
            get(action.arguments, "visibility", nothing)
        return Decision(
            action.tool_name == "write_note" && visibility == "public",
            "only public notes are permitted",
        )
    end
    Decision(false, "unsupported action")
end

function run_scenario(session_id::String, decision::InterruptDecision)
    effects = Ref(0)
    registry = ToolRegistry()
    PraxoCore.AgentRuntime.register!(registry, FuncTool(
        "write_note",
        "Write a short note with the requested visibility.",
        _ -> (effects[] += 1; "written"),
    ))
    options = AgentOptions(FixtureModel();
        interrupt_on = ["write_note"],
        on_interrupt_decision = _ -> decision)
    options.tools = registry
    options.max_steps = 3
    options.allowed_tools = ["write_note"]
    options.policy = NotePolicy()
    result = nothing
    caught = nothing
    try
        result = run_agent(Agent(options), Session(session_id), "Write a note.")
    catch error
        caught = error
    end
    (result, caught, effects[])
end

function run_example(output=stdout)
    result, caught, effects = run_scenario(
        "hitl-approve", InterruptDecision(INTERRUPT_APPROVE))
    if caught !== nothing || result === nothing || result.output != "done" || effects != 1
        error("approve scenario failed: output=$(result === nothing ? "<none>" : repr(result.output)) " *
              "effects=$effects error=$(caught === nothing ? "<none>" : sprint(showerror, caught))")
    end
    println(output, "approve: written; effects=1")

    result, caught, effects = run_scenario(
        "hitl-edit",
        InterruptDecision(INTERRUPT_EDIT;
            arguments = Dict{String,Any}("text" => "hello", "visibility" => "private")),
    )
    if !(caught isa PraxoError) || caught.code != "AGENT_POLICY_DENIED" || effects != 0
        error("edit scenario failed: effects=$effects " *
              "error=$(caught === nothing ? "<none>" : sprint(showerror, caught))")
    end
    println(output, "edit: policy rejected; effects=0")
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_example()
end
