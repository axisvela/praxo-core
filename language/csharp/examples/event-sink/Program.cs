using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.EventSink;

public static class Program
{
    public static string Run(IModel model, IEventSink allSink, IEventSink toolSink)
    {
        var tools = new ToolRegistry();
        tools.Register(new FuncTool(
            "lookup",
            "Look up a small status value.",
            arguments => JsonValue.Create("green")));
        var events = new MultiSink(new IEventSink[]
        {
            allSink,
            new FilterSink(toolSink, @event => @event.Type == "tool.call"),
        });
        var options = new AgentOptions(model)
        {
            Tools = tools,
            Events = events,
            SystemPrompt = "Use tools when asked for status.",
            MaxSteps = 3,
        };
        return new Agent(options)
            .Run(new Session("event-sink"), "Check the status.")
            .Output;
    }

    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            var allSink = new RecordingSink();
            var toolSink = new RecordingSink();
            var output = Run(new ToolThenAnswerModel(), allSink, toolSink);
            if (output != "status: green")
            {
                Console.Error.WriteLine($"unexpected output: {output}");
                return 1;
            }
            if (!allSink.Types.SequenceEqual(new[]
                {
                    "run.started",
                    "tool.call",
                    "run.completed",
                }))
            {
                Console.Error.WriteLine(
                    $"unexpected events: {string.Join(", ", allSink.Types)}");
                return 1;
            }
            if (!toolSink.Types.SequenceEqual(new[] { "tool.call" }))
            {
                Console.Error.WriteLine(
                    $"unexpected filtered events: {string.Join(", ", toolSink.Types)}");
                return 1;
            }
            if (toolSink.Events[0].Data?["name"]?.GetValue<string>() != "lookup")
            {
                Console.Error.WriteLine("tool.call did not include the tool name");
                return 1;
            }
            Console.WriteLine("event sink test: ok");
            return 0;
        }

        Console.WriteLine("Run with --test; wire real sinks in Program.Run.");
        return 0;
    }

    private sealed class RecordingSink : IEventSink
    {
        public List<Event> Events { get; } = new();

        public IReadOnlyList<string> Types => Events.Select(@event => @event.Type).ToList();

        public void Emit(Event @event) => Events.Add(@event);
    }

    private sealed class ToolThenAnswerModel : IModel
    {
        private int _calls;

        public Response Generate(Request request)
        {
            _calls += 1;
            if (_calls == 1)
            {
                var call = new ToolCall
                {
                    Id = "call-1",
                    Name = "lookup",
                    Arguments = new JsonObject { ["key"] = "status" },
                };
                return new Response
                {
                    Message = Message.Assistant("", new[] { call }),
                };
            }
            return new Response
            {
                Message = Message.Assistant("status: green"),
            };
        }
    }
}
