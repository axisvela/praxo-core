using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class AnthropicOptions
{
    public string ApiKey { get; set; } = "";

    public string Model { get; set; } = "";

    public string BaseUrl { get; set; } = "https://api.anthropic.com";

    public string Version { get; set; } = "2023-06-01";

    public int MaxTokens { get; set; } = 1024;

    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(60);
}

public sealed class AnthropicModel : IModel, IStreamingModel
{
    private readonly HttpClient _client;
    private readonly AnthropicOptions _options;

    public AnthropicModel(HttpClient client, AnthropicOptions options)
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
                $"anthropic: {(int)response.StatusCode}: {raw}");
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
                $"anthropic: {(int)response.StatusCode}: {error}");
        }
        using var stream = response.Content.ReadAsStream();
        using var reader = new StreamReader(stream);
        var content = new StringBuilder();
        var blocks = new Dictionary<int, BlockState>();
        long inputTokens = 0;
        long outputTokens = 0;
        long cachedTokens = 0;
        string? stopReason = null;
        var stopped = false;
        while (reader.ReadLine() is { } line)
        {
            if (!line.StartsWith("data:", StringComparison.Ordinal))
            {
                continue;
            }
            var data = line[5..].Trim();
            if (data.Length == 0)
            {
                continue;
            }
            var @event = Json.Parse(data);
            var type = Json.GetString(@event, "type");
            if (type == "message_start")
            {
                var usage = Json.Get(Json.Get(@event, "message"), "usage");
                inputTokens = Long(usage, "input_tokens") ?? 0;
                cachedTokens = Long(usage, "cache_read_input_tokens") ?? 0;
            }
            else if (type == "content_block_start")
            {
                var index = (int)(Long(@event, "index") ?? 0);
                var block = Json.Get(@event, "content_block") as JsonObject;
                var state = new BlockState
                {
                    Kind = Json.GetString(block, "type") ?? "",
                    Id = Json.GetString(block, "id") ?? "",
                    Name = Json.GetString(block, "name") ?? "",
                    Input = Json.Get(block, "input") as JsonObject ?? new JsonObject(),
                };
                blocks[index] = state;
                var text = Json.GetString(block, "text");
                if (!string.IsNullOrEmpty(text))
                {
                    content.Append(text);
                    onDelta(text);
                }
            }
            else if (type == "content_block_delta")
            {
                var index = (int)(Long(@event, "index") ?? 0);
                if (!blocks.TryGetValue(index, out var block))
                {
                    block = new BlockState();
                    blocks[index] = block;
                }
                var delta = Json.Get(@event, "delta");
                var deltaType = Json.GetString(delta, "type");
                if (deltaType == "text_delta")
                {
                    var text = Json.GetString(delta, "text") ?? "";
                    if (text.Length > 0)
                    {
                        content.Append(text);
                        onDelta(text);
                    }
                }
                else if (deltaType == "input_json_delta")
                {
                    block.Arguments.Append(Json.GetString(delta, "partial_json"));
                }
            }
            else if (type == "message_delta")
            {
                stopReason = Json.GetString(Json.Get(@event, "delta"), "stop_reason")
                    ?? stopReason;
                var usage = Json.Get(@event, "usage");
                outputTokens = Long(usage, "output_tokens") ?? 0;
                var input = Long(usage, "input_tokens");
                if (input is not null && input != 0)
                {
                    inputTokens = input.Value;
                }
            }
            else if (type == "message_stop")
            {
                stopped = true;
                break;
            }
            else if (type == "error")
            {
                throw new PraxoException(
                    "MODEL_HTTP",
                    $"anthropic: {Json.GetString(Json.Get(@event, "error"), "message")}");
            }
        }
        if (!stopped)
        {
            throw new PraxoException(
                "MODEL_STREAM",
                "anthropic: stream ended before completion");
        }
        var calls = new List<ToolCall>();
        foreach (var index in blocks.Keys.OrderBy(value => value))
        {
            var block = blocks[index];
            if (block.Kind != "tool_use")
            {
                continue;
            }
            var arguments = block.Input;
            if (block.Arguments.Length > 0)
            {
                try
                {
                    arguments = Json.Parse(block.Arguments.ToString()) as JsonObject
                        ?? new JsonObject();
                }
                catch (Exception)
                {
                    throw new PraxoException(
                        "MODEL_STREAM",
                        $"anthropic: tool {block.Name} arguments");
                }
            }
            calls.Add(new ToolCall
            {
                Id = block.Id.Length > 0 ? block.Id : $"call-{calls.Count + 1}",
                Name = block.Name,
                Arguments = arguments,
            });
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
            FinishReason = stopReason,
        };
    }

    private void Validate()
    {
        if (string.IsNullOrEmpty(_options.ApiKey))
        {
            throw new PraxoException("MODEL_CONFIG", "anthropic: API key is required");
        }
        if (string.IsNullOrEmpty(_options.Model))
        {
            throw new PraxoException("MODEL_CONFIG", "anthropic: model is required");
        }
    }

    private HttpRequestMessage RequestMessage(Request request, bool stream)
    {
        var message = new HttpRequestMessage(HttpMethod.Post, Endpoint());
        message.Headers.TryAddWithoutValidation("x-api-key", _options.ApiKey);
        message.Headers.TryAddWithoutValidation(
            "anthropic-version",
            string.IsNullOrEmpty(_options.Version) ? "2023-06-01" : _options.Version);
        message.Headers.Accept.ParseAdd(
            stream ? "text/event-stream" : "application/json");
        message.Content = new StringContent(
            Json.Stringify(BuildBody(request, stream)),
            Encoding.UTF8,
            "application/json");
        return message;
    }

    private string Endpoint()
        => _options.BaseUrl.TrimEnd('/') + "/v1/messages";

    private JsonObject BuildBody(Request request, bool stream)
    {
        var messages = new JsonArray();
        var system = new List<string>();
        var toolResults = new JsonArray();
        void Flush()
        {
            if (toolResults.Count == 0)
            {
                return;
            }
            messages.Add(new JsonObject
            {
                ["role"] = "user",
                ["content"] = toolResults.DeepClone(),
            });
            toolResults.Clear();
        }
        foreach (var msg in request.Messages)
        {
            if (msg.Role == Roles.System)
            {
                if (!string.IsNullOrEmpty(msg.Content))
                {
                    system.Add(msg.Content);
                }
                continue;
            }
            if (msg.Role == Roles.Tool)
            {
                toolResults.Add(new JsonObject
                {
                    ["type"] = "tool_result",
                    ["tool_use_id"] = msg.ToolId ?? "",
                    ["content"] = msg.Content ?? "",
                });
                continue;
            }
            Flush();
            var content = MessageContent(msg);
            if (content.Count > 0)
            {
                messages.Add(new JsonObject
                {
                    ["role"] = msg.Role,
                    ["content"] = content,
                });
            }
        }
        Flush();
        var body = new JsonObject
        {
            ["model"] = _options.Model,
            ["max_tokens"] = _options.MaxTokens <= 0 ? 1024 : _options.MaxTokens,
            ["messages"] = messages,
            ["stream"] = stream,
        };
        if (system.Count > 0)
        {
            body["system"] = string.Join("\n\n", system);
        }
        if (request.Tools.Count > 0)
        {
            body["tools"] = new JsonArray(request.Tools.Select(spec =>
                (JsonNode?)new JsonObject
                {
                    ["name"] = spec.Name,
                    ["description"] = spec.Description,
                    ["input_schema"] = spec.Parameters?.DeepClone()
                        ?? new JsonObject { ["type"] = "object", ["properties"] = new JsonObject() },
                }).ToArray());
            var choice = ToolChoice(request.ToolChoice);
            if (choice != null)
            {
                body["tool_choice"] = choice;
            }
        }
        if (request.Temperature != 0)
        {
            body["temperature"] = request.Temperature;
        }
        return body;
    }

    private static JsonArray MessageContent(Message message)
    {
        var content = new JsonArray();
        if (!string.IsNullOrEmpty(message.Content))
        {
            content.Add(new JsonObject { ["type"] = "text", ["text"] = message.Content });
        }
        foreach (var block in message.ContentBlocks)
        {
            if (block.Type == "text" && !string.IsNullOrEmpty(block.Text))
            {
                content.Add(new JsonObject { ["type"] = "text", ["text"] = block.Text });
            }
        }
        foreach (var call in message.ToolCalls)
        {
            content.Add(new JsonObject
            {
                ["type"] = "tool_use",
                ["id"] = call.Id,
                ["name"] = call.Name,
                ["input"] = call.Arguments.DeepClone(),
            });
        }
        return content;
    }

    private static JsonObject? ToolChoice(string? choice)
        => choice switch
        {
            "auto" => new JsonObject { ["type"] = "auto" },
            "required" => new JsonObject { ["type"] = "any" },
            "none" => new JsonObject { ["type"] = "none" },
            _ => null,
        };

    private static Response ParseResponse(JsonNode? data)
    {
        var error = Json.Get(data, "error");
        if (error != null)
        {
            throw new PraxoException(
                "MODEL_HTTP",
                $"anthropic: {Json.GetString(error, "message")}");
        }
        var text = new StringBuilder();
        var calls = new List<ToolCall>();
        var blocks = Json.Get(data, "content") as JsonArray;
        foreach (var block in blocks ?? new JsonArray())
        {
            var type = Json.GetString(block, "type");
            if (type == "text")
            {
                text.Append(Json.GetString(block, "text"));
            }
            else if (type == "tool_use")
            {
                calls.Add(new ToolCall
                {
                    Id = Json.GetString(block, "id")
                        ?? $"call-{calls.Count + 1}",
                    Name = Json.GetString(block, "name") ?? "",
                    Arguments = Json.Get(block, "input") as JsonObject ?? new JsonObject(),
                });
            }
        }
        var usage = Json.Get(data, "usage");
        return new Response
        {
            Message = Message.Assistant(text.ToString(), calls),
            Usage = new Usage
            {
                InputTokens = Long(usage, "input_tokens") ?? 0,
                OutputTokens = Long(usage, "output_tokens") ?? 0,
                CachedTokens = Long(usage, "cache_read_input_tokens") ?? 0,
            },
            FinishReason = Json.GetString(data, "stop_reason"),
        };
    }

    private static long? Long(JsonNode? node, string name)
        => node?[name] is JsonValue value && value.TryGetValue<long>(out var number)
            ? number
            : null;

    private sealed class BlockState
    {
        public string Kind { get; init; } = "";

        public string Id { get; init; } = "";

        public string Name { get; init; } = "";

        public JsonObject Input { get; init; } = new();

        public StringBuilder Arguments { get; } = new();
    }
}
