using System.Text.Json.Nodes;

namespace Praxo.Core;

public interface IModel
{
    Response Generate(Request request);
}

public interface IStreamingModel : IModel
{
    Response GenerateStream(Request request, Action<string> onDelta);
}

public interface ITool
{
    string Name { get; }

    string Description { get; }

    JsonNode? Invoke(JsonObject arguments);
}

public sealed class FuncTool : ITool
{
    private readonly Func<JsonObject, JsonNode?> _function;

    public string Name { get; }

    public string Description { get; }

    public FuncTool(string name, string description, Func<JsonObject, JsonNode?> function)
    {
        Name = name;
        Description = description;
        _function = function;
    }

    public JsonNode? Invoke(JsonObject arguments) => _function(arguments);
}

public sealed class ToolRegistry
{
    private readonly Dictionary<string, ITool> _tools = new(StringComparer.Ordinal);

    public void Register(ITool tool)
    {
        _tools[tool.Name] = tool;
    }

    public ITool Get(string name)
    {
        if (_tools.TryGetValue(name, out var tool))
        {
            return tool;
        }
        throw PraxoException.ToolNotFound($"tool not found: {name}");
    }

    public bool Contains(string name) => _tools.ContainsKey(name);

    public IReadOnlyList<ToolSpec> Specs()
        => _tools.Values
            .Select(tool => new ToolSpec { Name = tool.Name, Description = tool.Description })
            .OrderBy(spec => spec.Name, StringComparer.Ordinal)
            .ToList();

    public int Count => _tools.Count;
}

public sealed class StaticModel : IModel
{
    private readonly string _content;

    public StaticModel(string content)
    {
        _content = content;
    }

    public Response Generate(Request request) => new()
    {
        Message = Message.Assistant(_content),
    };
}
