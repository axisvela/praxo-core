using System.Text.Json;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public static class Json
{
    public static readonly JsonSerializerOptions Options = new()
    {
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull,
    };

    public static JsonNode? Parse(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return null;
        }
        using var document = JsonDocument.Parse(text);
        return JsonNode.Parse(document.RootElement.GetRawText());
    }

    public static string Stringify(JsonNode? node)
        => node?.ToJsonString(Options) ?? "null";

    public static JsonNode? Get(JsonNode? node, string name)
        => node is JsonObject obj && obj.TryGetPropertyValue(name, out var value) ? value : null;

    public static JsonObject Object(JsonNode? node)
        => node as JsonObject ?? new JsonObject();

    public static JsonArray Array(JsonNode? node)
        => node as JsonArray ?? new JsonArray();

    public static string? GetString(JsonNode? node, string name)
    {
        var value = Get(node, name);
        return value is JsonValue scalar && scalar.TryGetValue<string>(out var text)
            ? text
            : null;
    }

    public static bool GetBool(JsonNode? node, string name, bool fallback = false)
    {
        var value = Get(node, name);
        return value is JsonValue scalar && scalar.TryGetValue<bool>(out var result)
            ? result
            : fallback;
    }

    public static double GetNumber(JsonNode? node, string name, double fallback = 0)
    {
        var value = Get(node, name);
        return value is JsonValue scalar && scalar.TryGetValue<double>(out var result)
            ? result
            : fallback;
    }

    public static int GetInt(JsonNode? node, string name, int fallback = 0)
        => (int)GetNumber(node, name, fallback);

    public static bool DeepEquals(JsonNode? left, JsonNode? right)
        => JsonNode.DeepEquals(left, right);

    public static JsonNode? From<T>(T value)
        => JsonSerializer.SerializeToNode(value, Options);

    public static bool TryParseObject(string raw, out JsonObject obj)
    {
        obj = new JsonObject();
        try
        {
            var node = Parse(raw);
            if (node is JsonObject result)
            {
                obj = result;
                return true;
            }
        }
        catch (JsonException)
        {
        }
        return false;
    }
}
