using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace Praxo.Core;

public sealed class ParsedToolCall
{
    public string CallId { get; set; } = "";

    public string Name { get; set; } = "";

    public string Operation { get; set; } = "";

    public string Resource { get; set; } = "";

    public string Risk { get; set; } = "";

    public string Reason { get; set; } = "";

    public string IdempotencyKey { get; set; } = "";

    public JsonObject Input { get; set; } = new();
}

public static class ToolCallParser
{
    private static readonly Regex XmlTool = new(
        "<tool_call\\s+name=\"([^\"]+)\"\\s*>\\s*(.*?)\\s*</tool_call>",
        RegexOptions.Compiled | RegexOptions.Singleline);

    private static readonly Regex TagTool = new(
        "<([a-zA-Z][\\w-]*(?:\\.[\\w-]+)+)>\\s*(\\{.*?)\\s*(?:</[a-zA-Z][\\w.-]*>|$)",
        RegexOptions.Compiled | RegexOptions.Singleline);

    private static readonly Regex PlainTool = new(
        "^\\s*([a-zA-Z][\\w.-]*)\\s+(\\{.*\\})\\s*$",
        RegexOptions.Compiled | RegexOptions.Multiline);

    private static readonly Regex TripleNewlines = new(
        "\\n{3,}", RegexOptions.Compiled);

    private static readonly Regex[] StripPatterns =
    {
        new("<tool_call\\s+name=\"[^\"]+\"\\s*>.*?(?:</tool_call>|$)",
            RegexOptions.Compiled | RegexOptions.Singleline),
        new("<tool_call_invoke>.*?(?:</tool_call_invoke>|$)",
            RegexOptions.Compiled | RegexOptions.Singleline),
        new("<[a-zA-Z][\\w-]*(?:\\.[\\w-]+)+>\\s*\\{.*?(?:</[a-zA-Z][\\w.-]*>|$)",
            RegexOptions.Compiled | RegexOptions.Singleline),
    };

    public static ParsedToolCall? Parse(string content)
    {
        var call = ParseJson(content)
            ?? ParseXml(content)
            ?? ParseTag(content)
            ?? ParsePlain(content);
        if (call != null)
        {
            call.CallId = $"tc-{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        }
        return call;
    }

    public static string StripMarkup(string content)
    {
        var output = content;
        foreach (var pattern in StripPatterns)
        {
            output = pattern.Replace(output, "");
        }
        output = TripleNewlines.Replace(output, "\n\n");
        return output.Trim();
    }

    public static JsonObject? ParseInputJson(string raw)
    {
        if (Json.TryParseObject(raw.Trim(), out var direct))
        {
            return direct;
        }
        try
        {
            var escaped = raw.Replace("\\", "\\\\");
            if (Json.TryParseObject(escaped.Trim(), out var escapedObject))
            {
                return escapedObject;
            }
        }
        catch (System.Text.Json.JsonException)
        {
        }
        return null;
    }

    private static ParsedToolCall? ParseJson(string content)
    {
        if (!Json.TryParseObject(content, out var root))
        {
            return null;
        }
        var name = Json.GetString(root, "name");
        if (string.IsNullOrEmpty(name))
        {
            return null;
        }
        return new ParsedToolCall
        {
            Name = name,
            Input = Json.Get(root, "input") as JsonObject ?? new JsonObject(),
            Operation = Json.GetString(root, "operation") ?? "",
            Resource = Json.GetString(root, "resource") ?? "",
            Risk = Json.GetString(root, "risk") ?? "",
            Reason = Json.GetString(root, "reason") ?? "",
            IdempotencyKey = Json.GetString(root, "idempotency_key") ?? "",
        };
    }

    private static ParsedToolCall? ParseXml(string content)
    {
        var matches = XmlTool.Matches(content);
        if (matches.Count == 0)
        {
            return null;
        }
        var match = matches[^1];
        var input = ParseInputJson(match.Groups[2].Value);
        return input == null
            ? null
            : new ParsedToolCall { Name = match.Groups[1].Value, Input = input };
    }

    private static ParsedToolCall? ParseTag(string content)
    {
        var matches = TagTool.Matches(content);
        if (matches.Count == 0)
        {
            return null;
        }
        var match = matches[^1];
        var input = ParseInputJson(match.Groups[2].Value);
        return input == null
            ? null
            : new ParsedToolCall { Name = match.Groups[1].Value, Input = input };
    }

    private static ParsedToolCall? ParsePlain(string content)
    {
        var matches = PlainTool.Matches(content);
        if (matches.Count == 0)
        {
            return null;
        }
        var match = matches[^1];
        var name = match.Groups[1].Value;
        if (!name.Contains('.'))
        {
            return null;
        }
        var input = ParseInputJson(match.Groups[2].Value);
        return input == null
            ? null
            : new ParsedToolCall { Name = name, Input = input };
    }
}
