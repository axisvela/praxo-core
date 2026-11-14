push!(LOAD_PATH, "language/julia/src")
using PraxoCore

mutable struct RecordingSink <: AbstractSink
    kinds::Vector{String}
end
RecordingSink() = RecordingSink(String[])
emit(sink::RecordingSink, event) = push!(sink.kinds, event.type)

all = RecordingSink()
tool = RecordingSink()
filtered = FilterSink(tool, event -> event.type == "tool.call")
multi = MultiSink(AbstractSink[all, filtered])
for kind in ["run.started", "tool.call", "run.completed"]
    emit(multi, Event(kind, "s1"))
end
@assert all.kinds == ["run.started", "tool.call", "run.completed"]
@assert tool.kinds == ["tool.call"]
println("Julia event sink example passed")
