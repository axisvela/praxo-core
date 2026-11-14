require_relative 'event_sink'

all_sink = EventSinkExample::RecordingSink.new
tool_sink = EventSinkExample::RecordingSink.new
output = EventSinkExample.run(all_sink, tool_sink)

raise "unexpected output: #{output.inspect}" unless output == 'status: green'
unless all_sink.types == %w[run.started tool.call run.completed]
  raise "unexpected events: #{all_sink.types.inspect}"
end
raise "unexpected filtered events: #{tool_sink.types.inspect}" unless tool_sink.types == ['tool.call']
raise 'tool name missing' unless tool_sink.events.first.data['name'] == 'lookup'

puts 'ruby event sink tests passed'
