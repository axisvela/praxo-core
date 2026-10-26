using System.Text.Json.Nodes;
using System.Text.Json.Serialization;

namespace Praxo.Core;

public static class Roles
{
    public const string System = "system";
    public const string User = "user";
    public const string Assistant = "assistant";
    public const string Tool = "tool";
}

public sealed class ContentBlock
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "";

    [JsonPropertyName("text")]
    public string? Text { get; set; }

    [JsonPropertyName("image_url")]
    public string? ImageUrl { get; set; }

    [JsonPropertyName("data")]
    public string? Data { get; set; }

    public static ContentBlock TextBlock(string text)
        => new() { Type = "text", Text = text };
}

public sealed class ToolCall
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("arguments")]
    public JsonObject Arguments { get; set; } = new();
}

public sealed class Message
{
    [JsonPropertyName("role")]
    public string Role { get; set; } = "";

    [JsonPropertyName("content")]
    public string? Content { get; set; }

    [JsonPropertyName("contentBlocks")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public List<ContentBlock> ContentBlocks { get; set; } = new();

    [JsonPropertyName("toolCalls")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public List<ToolCall> ToolCalls { get; set; } = new();

    [JsonPropertyName("toolId")]
    public string? ToolId { get; set; }

    public static Message Text(string role, string content)
        => new() { Role = role, Content = content };

    public static Message Assistant(string content, IEnumerable<ToolCall>? toolCalls = null)
        => new()
        {
            Role = Roles.Assistant,
            Content = content,
            ToolCalls = toolCalls?.ToList() ?? new List<ToolCall>(),
        };

    public static Message Tool(string content, string toolId)
        => new() { Role = Roles.Tool, Content = content, ToolId = toolId };
}

public sealed class ToolSpec
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("description")]
    public string Description { get; set; } = "";

    [JsonPropertyName("parameters")]
    public JsonObject? Parameters { get; set; }

    [JsonPropertyName("risk")]
    public string? Risk { get; set; }
}

public sealed class Usage
{
    [JsonPropertyName("inputTokens")]
    public long InputTokens { get; set; }

    [JsonPropertyName("outputTokens")]
    public long OutputTokens { get; set; }

    [JsonPropertyName("cachedTokens")]
    public long CachedTokens { get; set; }

    public Usage Plus(Usage other) => new()
    {
        InputTokens = InputTokens + other.InputTokens,
        OutputTokens = OutputTokens + other.OutputTokens,
        CachedTokens = CachedTokens + other.CachedTokens,
    };
}

public sealed class ResponseFormat
{
    [JsonPropertyName("name")]
    public string? Name { get; set; }

    [JsonPropertyName("schema")]
    public JsonObject? Schema { get; set; }
}

public sealed class Request
{
    [JsonPropertyName("messages")]
    public List<Message> Messages { get; set; } = new();

    [JsonPropertyName("tools")]
    public List<ToolSpec> Tools { get; set; } = new();

    [JsonPropertyName("toolChoice")]
    public string? ToolChoice { get; set; }

    [JsonPropertyName("responseFormat")]
    public ResponseFormat? ResponseFormat { get; set; }

    [JsonPropertyName("temperature")]
    public double Temperature { get; set; }

    public static Request Of(IEnumerable<Message> messages)
        => new() { Messages = messages.ToList() };
}

public sealed class Response
{
    public Message Message { get; set; } = new();

    public Usage Usage { get; set; } = new();

    public string? FinishReason { get; set; }
}

public sealed class Session
{
    public string Id { get; set; }

    public string TenantId { get; set; } = "default";

    public string WorkspaceId { get; set; } = "";

    public List<Message> Messages { get; set; } = new();

    public Session(string id)
    {
        Id = id;
    }
}

public sealed class RunResult
{
    public string RunId { get; set; } = "";

    public string Output { get; set; } = "";

    public int Steps { get; set; }

    public Usage Usage { get; set; } = new();
}

public sealed class MemoryRecord
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("frame")]
    public string Frame { get; set; } = "";

    [JsonPropertyName("content")]
    public string Content { get; set; } = "";

    [JsonPropertyName("metadata")]
    public JsonObject? Metadata { get; set; }

    [JsonPropertyName("createdAt")]
    public string? CreatedAt { get; set; }
}

public sealed class PathGrant
{
    public string Root { get; set; } = "";

    public string Access { get; set; } = "read";
}

public sealed class Action
{
    public string Kind { get; set; } = "";

    public string SessionId { get; set; } = "";

    public string? ToolName { get; set; }

    public JsonObject? Arguments { get; set; }
}

public sealed class Decision
{
    public bool Allowed { get; set; }

    public string Reason { get; set; } = "";

    public static Decision Allow(string reason) => new() { Allowed = true, Reason = reason };

    public static Decision Deny(string reason) => new() { Allowed = false, Reason = reason };
}

public sealed class StreamPart
{
    public string RunId { get; set; } = "";

    public string SessionId { get; set; } = "";

    public string Kind { get; set; } = "";

    public int Step { get; set; }

    public JsonNode? Data { get; set; }

    public string? At { get; set; }
}

public static class StreamKinds
{
    public const string Values = "values";
    public const string Updates = "updates";
    public const string Messages = "messages";
    public const string Tasks = "tasks";
    public const string Debug = "debug";
    public const string Checkpoint = "checkpoint";

    public static readonly string[] All =
    {
        Values, Updates, Messages, Tasks, Debug, Checkpoint,
    };
}
