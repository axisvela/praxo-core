using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class GeminiOptions
{
    public string ApiKey { get; set; } = "";

    public string Model { get; set; } = "";

    public string BaseUrl { get; set; } = "https://generativelanguage.googleapis.com";

    public int MaxOutputTokens { get; set; }

    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(60);
}

public sealed class GeminiModel : IModel, IStreamingModel
{
    private readonly HttpClient _client;
    private readonly GeminiOptions _options;

    public GeminiModel(HttpClient client, GeminiOptions options)
    {
        _client = client;
        _options = options;
    }

    public Response Generate(Request request)
    {
        Validate();
        using var message = RequestMessage(request, false);
        using var response = _client.Send(message);
        var raw = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        if (!response.IsSuccessStatusCode)
        {
            throw new PraxoException(
                "MODEL_HTTP",
                $"gemini: {(int)response.StatusCode}: {raw}");
        }
        return ParseResponse(Json.Parse(raw));
    }

    public Response GenerateStream(Request request, Action<string> onDelta)
    {
        Validate();
        using var message = RequestMessage(request, true);
        using var response = _client.Send(
            message,
            HttpCompletionOption.ResponseHeadersRead);
        if (!response.IsSuccessStatusCode)
        {
            var error = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
            throw new PraxoException(
                "MODEL_HTTP",
                $"gemini: {(int)response.StatusCode}: {error}");
        }
        using var stream = response.Content.ReadAsStream();
        using var reader = new StreamReader(stream);
        var content = new StringBuilder();
        var calls = new List<ToolCall>();
        long inputTokens = 0;
        long outputTokens = 0;
        long cachedTokens = 0;
        string? finishReason = null;
        while (reader.ReadLine() is { } line)
        {
            if (!line.StartsWith("data:", StringComparison.Ordinal))
            {
                continue;
            }
            var data = line[5..].Trim();
            if (data.Length == 0 || data == "[DONE]")
            {
                continue;
            }
            var chunk = Json.Parse(data);
            var error = Json.Get(chunk, "error");
            if (error != null)
            {
                throw new PraxoException(
                    "MODEL_HTTP",
                    $"gemini: {Json.GetString(error, "message")}");
            }
            var usage = Json.Get(chunk, "usageMetadata");
            inputTokens = Long(usage, "promptTokenCount") ?? inputTokens;
            outputTokens = Long(usage, "candidatesTokenCount") ?? outputTokens;
            cachedTokens = Long(usage, "cachedContentTokenCount") ?? cachedTokens;
            var candidates = Json.Get(chunk, "candidates") as JsonArray;
            foreach (var candidate in candidates ?? new JsonArray())
            {
                finishReason = Json.GetString(candidate, "finishReason")
                    ?? finishReason;
                var parts = Json.Get(Json.Get(candidate, "content"), "parts")
                    as JsonArray;
                foreach (var part in parts ?? new JsonArray())
                {
                    var text = Json.GetString(part, "text");
                    if (!string.IsNullOrEmpty(text))
                    {
                        content.Append(text);
                        onDelta(text);
                    }
                    var call = Json.Get(part, "functionCall");
                    if (call != null)
                    {
                        calls.Add(new ToolCall
                        {
                            Id = $"call-{calls.Count + 1}",
                            Name = Json.GetString(call, "name") ?? "",
                            Arguments = Json.Get(call, "args") as JsonObject
                                ?? new JsonObject(),
                        });
                    }
                }
            }
        }
        return new Response
        {
            Message = Message.Assistant(content.ToString(), calls),
            Usage = new Usage
            {
                InputTokens = inputTokens,
                OutputTokens = outputTokens,
                CachedTokens = cachedTokens,
            },
            FinishReason = finishReason,
        };
    }

    private void Validate()
    {
        if (string.IsNullOrEmpty(_options.ApiKey))
        {
            throw new PraxoException("MODEL_CONFIG", "gemini: API key is required");
        }
        if (string.IsNullOrEmpty(_options.Model))
        {
            throw new PraxoException("MODEL_CONFIG", "gemini: model is required");
        }
    }

    private HttpRequestMessage RequestMessage(Request request, bool stream)
    {
        var message = new HttpRequestMessage(HttpMethod.Post, Endpoint(stream));
        message.Headers.TryAddWithoutValidation("x-goog-api-key", _options.ApiKey);
        message.Headers.Accept.ParseAdd(
            stream ? "text/event-stream" : "application/json");
        message.Content = new StringContent(
            Json.Stringify(BuildBody(request)),
            Encoding.UTF8,
            "application/json");
        return message;
    }

    private string Endpoint(bool stream)
    {
        var root = _options.BaseUrl.TrimEnd('/');
        var model = Uri.EscapeDataString(_options.Model);
        return stream
            ? $"{root}/v1beta/models/{model}:streamGenerateContent?alt=sse"
            : $"{root}/v1beta/models/{model}:generateContent";
    }

    private JsonObject BuildBody(Request request)
    {
        var systemParts = new JsonArray();
        var contents = new JsonArray();
        var toolParts = new JsonArray();
        var names = new Dictionary<string, string>(StringComparer.Ordinal);
        void Flush()
        {
            if (toolParts.Count == 0)
            {
                return;
            }
            contents.Add(new JsonObject
            {
                ["role"] = "user",
                ["parts"] = toolParts.DeepClone(),
            });
            toolParts.Clear();
        }
        foreach (var msg in request.Messages)
        {
            if (msg.Role == Roles.System)
            {
                if (!string.IsNullOrEmpty(msg.Content))
                {
                    systemParts.Add(new JsonObject { ["text"] = msg.Content });
                }
                continue;
            }
            if (msg.Role == Roles.Tool)
            {
                var name = msg.ToolId != null && names.TryGetValue(msg.ToolId, out var known)
                    ? known
                    : msg.ToolId ?? "tool";
                toolParts.Add(new JsonObject
                {
                    ["functionResponse"] = new JsonObject
                    {
                        ["name"] = name,
                        ["response"] = new JsonObject { ["result"] = msg.Content ?? "" },
                    },
                });
                continue;
            }
            Flush();
            var parts = MessageParts(msg);
            if (parts.Count == 0)
            {
                continue;
            }
            contents.Add(new JsonObject
            {
                ["role"] = msg.Role == Roles.Assistant ? "model" : "user",
                ["parts"] = parts,
            });
            foreach (var call in msg.ToolCalls)
            {
                if (call.Id.Length > 0 && call.Name.Length > 0)
                {
                    names[call.Id] = call.Name;
                }
            }
        }
        Flush();
        var body = new JsonObject { ["contents"] = contents };
        if (systemParts.Count > 0)
        {
            body["system_instruction"] = new JsonObject
            {
                ["parts"] = systemParts,
            };
        }
        if (request.Tools.Count > 0)
        {
            body["tools"] = new JsonArray
            {
                new JsonObject
                {
                    ["functionDeclarations"] = new JsonArray(
                        request.Tools.Select(spec => (JsonNode?)new JsonObject
                        {
                            ["name"] = spec.Name,
                            ["description"] = spec.Description,
                            ["parameters"] = spec.Parameters?.DeepClone()
                                ?? new JsonObject
                                {
                                    ["type"] = "object",
                                    ["properties"] = new JsonObject(),
                                },
                        }).ToArray()),
                },
            };
            body["toolConfig"] = new JsonObject
            {
                ["functionCallingConfig"] = new JsonObject
                {
                    ["mode"] = ToolMode(request.ToolChoice),
                },
            };
        }
        if (request.Temperature != 0 || _options.MaxOutputTokens > 0)
        {
            body["generationConfig"] = new JsonObject
            {
                ["temperature"] = request.Temperature,
                ["maxOutputTokens"] = _options.MaxOutputTokens,
            };
        }
        return body;
    }

    private static JsonArray MessageParts(Message message)
    {
        var parts = new JsonArray();
        if (!string.IsNullOrEmpty(message.Content))
        {
            parts.Add(new JsonObject { ["text"] = message.Content });
        }
        foreach (var block in message.ContentBlocks)
        {
            if (block.Type == "text" && !string.IsNullOrEmpty(block.Text))
            {
                parts.Add(new JsonObject { ["text"] = block.Text });
            }
        }
        foreach (var call in message.ToolCalls)
        {
            parts.Add(new JsonObject
            {
                ["functionCall"] = new JsonObject
                {
                    ["name"] = call.Name,
                    ["args"] = call.Arguments.DeepClone(),
                },
            });
        }
        return parts;
    }

    private static string ToolMode(string? choice)
        => choice switch
        {
            "required" => "ANY",
            "none" => "NONE",
            _ => "AUTO",
        };

    private static Response ParseResponse(JsonNode? data)
    {
        var error = Json.Get(data, "error");
        if (error != null)
        {
            throw new PraxoException(
                "MODEL_HTTP",
                $"gemini: {Json.GetString(error, "message")}");
        }
        var candidates = Json.Get(data, "candidates") as JsonArray;
        if (candidates == null || candidates.Count == 0)
        {
            throw new PraxoException("MODEL_HTTP", "gemini: empty response");
        }
        var candidate = candidates[0];
        var text = new StringBuilder();
        var calls = new List<ToolCall>();
        var parts = Json.Get(Json.Get(candidate, "content"), "parts") as JsonArray;
        foreach (var part in parts ?? new JsonArray())
        {
            var value = Json.GetString(part, "text");
            if (!string.IsNullOrEmpty(value))
            {
                text.Append(value);
            }
            var call = Json.Get(part, "functionCall");
            if (call != null)
            {
                calls.Add(new ToolCall
                {
                    Id = $"call-{calls.Count + 1}",
                    Name = Json.GetString(call, "name") ?? "",
                    Arguments = Json.Get(call, "args") as JsonObject
                        ?? new JsonObject(),
                });
            }
        }
        var usage = Json.Get(data, "usageMetadata");
        return new Response
        {
            Message = Message.Assistant(text.ToString(), calls),
            Usage = new Usage
            {
                InputTokens = Long(usage, "promptTokenCount") ?? 0,
                OutputTokens = Long(usage, "candidatesTokenCount") ?? 0,
                CachedTokens = Long(usage, "cachedContentTokenCount") ?? 0,
            },
            FinishReason = Json.GetString(candidate, "finishReason"),
        };
    }

    private static long? Long(JsonNode? node, string name)
        => node?[name] is JsonValue value && value.TryGetValue<long>(out var number)
            ? number
            : null;
}
