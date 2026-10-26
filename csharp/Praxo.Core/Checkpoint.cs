using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class CheckpointAllowlist
{
    private readonly HashSet<string> _registered = new(StringComparer.Ordinal);

    public void Register(string typeName)
    {
        if (string.IsNullOrEmpty(typeName))
        {
            throw PraxoException.Checkpoint("checkpoint: allowlist type name is required");
        }
        _registered.Add(typeName);
    }

    public string Marshal(string typeName, JsonNode? value)
    {
        if (!_registered.Contains(typeName))
        {
            throw PraxoException.TypeNotAllowed($"checkpoint: payload type not allowed: {typeName}");
        }
        var envelope = new JsonObject
        {
            ["type"] = typeName,
            ["data"] = value?.DeepClone(),
        };
        return Json.Stringify(envelope);
    }

    public JsonNode? Unmarshal(string data)
    {
        JsonObject envelope;
        try
        {
            envelope = Json.Parse(data) as JsonObject
                ?? throw PraxoException.Checkpoint("checkpoint: envelope must be an object");
        }
        catch (System.Text.Json.JsonException ex)
        {
            throw PraxoException.Checkpoint($"checkpoint: {ex.Message}");
        }
        var typeName = Json.GetString(envelope, "type") ?? "";
        if (!_registered.Contains(typeName))
        {
            throw PraxoException.TypeNotAllowed($"checkpoint: payload type not allowed: {typeName}");
        }
        return Json.Get(envelope, "data")?.DeepClone();
    }
}
