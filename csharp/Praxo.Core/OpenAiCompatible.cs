using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class OpenAiCompatibleOptions
{
    public string BaseUrl { get; set; } = "https://api.openai.com/v1";

    public string ApiKey { get; set; } = "";

    public string Model { get; set; } = "";

    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(60);
}

public sealed class OpenAiCompatibleModel : IModel, IStreamingModel
{
    private readonly HttpClient _client;
    private readonly OpenAiCompatibleOptions _options;

    public OpenAiCompatibleModel(HttpClient client, OpenAiCompatibleOptions options)
    {
        _client = client;
        _options = options;
    }

    public Response Generate(Request request)
    {
        var body = BuildBody(request, false);
        using var message = new HttpRequestMessage(HttpMethod.Post, Endpoint());
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.ApiKey);
        message.Content = new StringContent(Json.Stringify(body), Encoding.UTF8, "application/json");
        using var response = _client.Send(message);
        var raw = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        if (!response.IsSuccessStatusCode)
        {
            throw new PraxoException("MODEL_HTTP", $"openai-compatible: {(int)response.StatusCode}: {raw}");
        }
        return ParseResponse(Json.Parse(raw));
    }

    public Response GenerateStream(Request request, Action<string> onDelta)
    {
        var body = BuildBody(request, true);
        using var message = new HttpRequestMessage(HttpMethod.Post, Endpoint());
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.ApiKey);
        message.Content = new StringContent(Json.Stringify(body), Encoding.UTF8, "application/json");
        using var response = _client.Send(message, HttpCompletionOption.ResponseHeadersRead);
        if (!response.IsSuccessStatusCode)
        {
            var error = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
            throw new PraxoException("MODEL_HTTP", $"openai-compatible: {(int)response.StatusCode}: {error}");
        }
        using var stream = response.Content.ReadAsStream();
        using var reader = new StreamReader(stream);
        var content = new StringBuilder();
        while (reader.ReadLine() is { } line)
        {
            if (!line.StartsWith("data: ", StringComparison.Ordinal))
            {
                continue;
            }
            var data = line[6..].Trim();
            if (data == "[DONE]")
            {
                break;
            }
            var chunk = Json.Parse(data);
            var delta = Json.GetString(Json.Get(Json.Get(chunk, "choices")?[0], "delta"), "content");
            if (!string.IsNullOrEmpty(delta))
            {
                content.Append(delta);
                onDelta(delta);
            }
        }
        return new Response { Message = Message.Assistant(content.ToString()) };
    }

    private string Endpoint()
    {
        var root = _options.BaseUrl.TrimEnd('/');
        return root.EndsWith("/chat/completions", StringComparison.Ordinal)
            ? root
            : root + "/chat/completions";
    }

    private JsonObject BuildBody(Request request, bool stream)
    {
        var messages = new JsonArray();
        foreach (var msg in request.Messages)
        {
            var item = new JsonObject { ["role"] = msg.Role };
            if (msg.Content != null)
            {
                item["content"] = msg.Content;
            }
            if (msg.ToolCalls.Count > 0)
            {
                item["tool_calls"] = new JsonArray(msg.ToolCalls.Select(call =>
                    (JsonNode?)new JsonObject
                    {
                        ["id"] = call.Id,
                        ["type"] = "function",
                        ["function"] = new JsonObject
                        {
                            ["name"] = call.Name,
                            ["arguments"] = Json.Stringify(call.Arguments),
                        },
                    }).ToArray());
            }
            if (msg.ToolId != null)
            {
                item["tool_call_id"] = msg.ToolId;
            }
            messages.Add(item);
        }
        var body = new JsonObject
        {
            ["model"] = _options.Model,
            ["messages"] = messages,
            ["stream"] = stream,
        };
        if (request.Temperature > 0)
        {
            body["temperature"] = request.Temperature;
        }
        if (request.Tools.Count > 0)
        {
            body["tools"] = new JsonArray(request.Tools.Select(tool => (JsonNode?)new JsonObject
            {
                ["type"] = "function",
                ["function"] = new JsonObject
                {
                    ["name"] = tool.Name,
                    ["description"] = tool.Description,
                    ["parameters"] = tool.Parameters?.DeepClone(),
                },
            }).ToArray());
        }
        if (request.ToolChoice != null)
        {
            body["tool_choice"] = request.ToolChoice;
        }
        if (request.ResponseFormat?.Schema != null)
        {
            body["response_format"] = new JsonObject
            {
                ["type"] = "json_schema",
                ["json_schema"] = new JsonObject
                {
                    ["name"] = request.ResponseFormat.Name ?? "structured_output",
                    ["schema"] = request.ResponseFormat.Schema.DeepClone(),
                },
            };
        }
        return body;
    }

    private static Response ParseResponse(JsonNode? root)
    {
        var choice = Json.Get(root, "choices")?[0];
        var message = Json.Get(choice, "message");
        var content = Json.GetString(message, "content") ?? "";
        var calls = new List<ToolCall>();
        foreach (var item in Json.Array(Json.Get(message, "tool_calls")))
        {
            var function = Json.Get(item, "function");
            var arguments = Json.GetString(function, "arguments");
            calls.Add(new ToolCall
            {
                Id = Json.GetString(item, "id") ?? "",
                Name = Json.GetString(function, "name") ?? "",
                Arguments = arguments != null && Json.TryParseObject(arguments, out var parsed)
                    ? parsed
                    : new JsonObject(),
            });
        }
        var usage = Json.Get(root, "usage");
        return new Response
        {
            Message = Message.Assistant(content, calls),
            Usage = new Usage
            {
                InputTokens = Json.GetInt(usage, "prompt_tokens"),
                OutputTokens = Json.GetInt(usage, "completion_tokens"),
            },
            FinishReason = Json.GetString(choice, "finish_reason"),
        };
    }
}
