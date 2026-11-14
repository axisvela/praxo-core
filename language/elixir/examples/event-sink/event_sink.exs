alias Praxo.{Models, Sink}

all = Sink.new()
tool = Sink.new()
filtered = Sink.filter(tool, ["tool.call"])
multi = Sink.multi([all, filtered])

events = [
  Models.event("run.started", "s1"),
  Models.event("tool.call", "s1"),
  Models.event("run.completed", "s1")
]

result = Enum.reduce(events, multi, fn event, sink -> Sink.emit(sink, event) end)
[all_result, filter_result] = result.sinks

unless all_result.kinds == ["run.started", "tool.call", "run.completed"] do
  raise "unexpected events: #{inspect(all_result.kinds)}"
end

unless filter_result.target.kinds == ["tool.call"] do
  raise "unexpected filtered events: #{inspect(filter_result.target.kinds)}"
end

IO.puts("Elixir event sink example passed")
