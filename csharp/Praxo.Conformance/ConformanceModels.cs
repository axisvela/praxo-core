using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Conformance;

internal sealed class ConformanceException : Exception
{
    public ConformanceException(string message) : base(message)
    {
    }
}

internal static class Assert
{
    public static void True(bool condition, string message)
    {
        if (!condition)
        {
            throw new ConformanceException(message);
        }
    }
}

internal sealed class RecordingSink : IEventSink
{
    public List<string> Types { get; } = new();

    public void Emit(Event @event) => Types.Add(@event.Type);
}

internal sealed class ScriptedModel : IModel
{
    private readonly JsonArray _steps;
    private readonly object _lock = new();
    private int _next;

    public ScriptedModel(JsonArray steps)
    {
        _steps = steps;
    }

    public Response Generate(Request request)
    {
        lock (_lock)
        {
            if (_next >= _steps.Count)
            {
                throw new PraxoException("SCRIPT", "script exhausted");
            }
            var step = _steps[_next]!;
            _next++;
            var calls = new List<ToolCall>();
            foreach (var item in Json.Array(Json.Get(step, "toolCalls")))
            {
                calls.Add(new ToolCall
                {
                    Id = Json.GetString(item, "id") ?? "",
                    Name = Json.GetString(item, "name") ?? "",
                    Arguments = Json.Get(item, "arguments") as JsonObject ?? new JsonObject(),
                });
            }
            return new Response
            {
                Message = Message.Assistant(Json.GetString(step, "content") ?? "", calls),
                Usage = new Usage
                {
                    InputTokens = Json.GetInt(step, "inputTokens"),
                    OutputTokens = Json.GetInt(step, "outputTokens"),
                },
            };
        }
    }
}

internal sealed class EchoTool : ITool
{
    private readonly System.Action _onInvoke;

    public string Name { get; }

    public string Description { get; }

    public EchoTool(string name, string description, System.Action onInvoke)
    {
        Name = name;
        Description = description;
        _onInvoke = onInvoke;
    }

    public JsonNode? Invoke(JsonObject arguments)
    {
        _onInvoke();
        return arguments.DeepClone();
    }
}

internal sealed class FixedSelector : IToolSelector
{
    private readonly List<string> _names;

    public FixedSelector(IEnumerable<string> names)
    {
        _names = names.ToList();
    }

    public List<string> Select(string query, IReadOnlyList<ToolSpec> tools) => _names.ToList();
}
