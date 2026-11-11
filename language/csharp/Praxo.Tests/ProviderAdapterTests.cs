using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tests;

internal static class ProviderAdapterTests
{
    private static int _passed;

    public static int Run()
    {
        TestAnthropicGenerate();
        TestAnthropicStream();
        TestGeminiGenerate();
        TestGeminiStream();
        TestMissingCredentials();
        return _passed;
    }

    private static void TestAnthropicGenerate()
    {
        var handler = new CaptureHandler(
            """
            {"content":[{"type":"text","text":"hello"},{"type":"tool_use","id":"tool-1","name":"echo","input":{"text":"hi"}}],"stop_reason":"end_turn","usage":{"input_tokens":3,"output_tokens":4,"cache_read_input_tokens":2}}
            """);
        var model = new AnthropicModel(
            new HttpClient(handler),
            new AnthropicOptions
            {
                ApiKey = "ak",
                Model = "claude-test",
                BaseUrl = "http://localhost",
            });
        var response = model.Generate(Request());
        Check(response.Message.Content == "hello", "anthropic content");
        Check(response.Message.ToolCalls[0].Id == "tool-1", "anthropic call id");
        Check(
            response.Message.ToolCalls[0].Arguments["text"]?.GetValue<string>() == "hi",
            "anthropic call arguments");
        Check(response.Usage.CachedTokens == 2, "anthropic cached tokens");
        Check(response.FinishReason == "end_turn", "anthropic finish");
        Check(handler.Headers["x-api-key"] == "ak", "anthropic api key");
        Check(handler.Headers["anthropic-version"] == "2023-06-01", "anthropic version");
        Check(handler.Body!["system"]?.GetValue<string>() == "be brief", "anthropic system");
        Check(
            handler.Body!["tools"]![0]!["input_schema"]!["type"]!.GetValue<string>()
                == "object",
            "anthropic tools");
        Check(
            handler.Body!["tool_choice"]!["type"]!.GetValue<string>() == "auto",
            "anthropic tool choice");
    }

    private static void TestAnthropicStream()
    {
        var events = new[]
        {
            """{"type":"message_start","message":{"usage":{"input_tokens":3}}}""",
            """{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}""",
            """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"he"}}""",
            """{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"llo"}}""",
            """{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"tool-1","name":"echo","input":{}}}""",
            """{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"text\":"}}""",
            """{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"hi\"}"}}""",
            """{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":4}}""",
            """{"type":"message_stop"}""",
        };
        var handler = new CaptureHandler(string.Join(
            "\n",
            events.Select(item => $"data: {item}\n")));
        var model = new AnthropicModel(
            new HttpClient(handler),
            new AnthropicOptions
            {
                ApiKey = "ak",
                Model = "claude-test",
                BaseUrl = "http://localhost",
            });
        var deltas = new List<string>();
        var response = model.GenerateStream(Request(), deltas.Add);
        Check(deltas.SequenceEqual(new[] { "he", "llo" }), "anthropic deltas");
        Check(response.Message.Content == "hello", "anthropic stream content");
        Check(
            response.Message.ToolCalls[0].Arguments["text"]?.GetValue<string>() == "hi",
            "anthropic stream arguments");
        Check(response.Usage.OutputTokens == 4, "anthropic stream usage");
    }

    private static void TestGeminiGenerate()
    {
        var handler = new CaptureHandler(
            """
            {"candidates":[{"content":{"role":"model","parts":[{"text":"hello"},{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":4,"cachedContentTokenCount":2}}
            """);
        var model = new GeminiModel(
            new HttpClient(handler),
            new GeminiOptions
            {
                ApiKey = "gk",
                Model = "gemini-test",
                BaseUrl = "http://localhost",
            });
        var response = model.Generate(Request());
        Check(response.Message.Content == "hello", "gemini content");
        Check(response.Message.ToolCalls[0].Name == "echo", "gemini call name");
        Check(response.Usage.InputTokens == 3, "gemini usage");
        Check(response.FinishReason == "STOP", "gemini finish");
        Check(handler.Headers["x-goog-api-key"] == "gk", "gemini api key");
        Check(
            handler.Body!["system_instruction"]!["parts"]![0]!["text"]!
                .GetValue<string>() == "be brief",
            "gemini system");
        Check(
            handler.Body!["toolConfig"]!["functionCallingConfig"]!["mode"]!
                .GetValue<string>() == "AUTO",
            "gemini tool mode");
    }

    private static void TestGeminiStream()
    {
        var events = new[]
        {
            """{"candidates":[{"content":{"parts":[{"text":"he"}]}}]}""",
            """{"candidates":[{"content":{"parts":[{"text":"llo"}]}}]}""",
            """{"candidates":[{"content":{"parts":[{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":4}}""",
        };
        var handler = new CaptureHandler(string.Join(
            "\n",
            events.Select(item => $"data: {item}\n")));
        var model = new GeminiModel(
            new HttpClient(handler),
            new GeminiOptions
            {
                ApiKey = "gk",
                Model = "gemini-test",
                BaseUrl = "http://localhost",
            });
        var deltas = new List<string>();
        var response = model.GenerateStream(Request(), deltas.Add);
        Check(deltas.SequenceEqual(new[] { "he", "llo" }), "gemini deltas");
        Check(
            response.Message.ToolCalls[0].Arguments["text"]?.GetValue<string>() == "hi",
            "gemini stream arguments");
        Check(response.FinishReason == "STOP", "gemini stream finish");
    }

    private static void TestMissingCredentials()
    {
        try
        {
            new AnthropicModel(
                new HttpClient(new CaptureHandler("{}")),
                new AnthropicOptions { Model = "m" }).Generate(Request());
            throw new InvalidOperationException("expected anthropic key error");
        }
        catch (PraxoException error)
        {
            Check(error.Message.Contains("API key"), "anthropic key error");
        }
        try
        {
            new GeminiModel(
                new HttpClient(new CaptureHandler("{}")),
                new GeminiOptions { Model = "m" }).Generate(Request());
            throw new InvalidOperationException("expected gemini key error");
        }
        catch (PraxoException error)
        {
            Check(error.Message.Contains("API key"), "gemini key error");
        }
    }

    private static Request Request()
        => new()
        {
            Messages = new List<Message>
            {
                Message.Text(Roles.System, "be brief"),
                Message.Text(Roles.User, "hi"),
            },
            Tools = new List<ToolSpec>
            {
                new()
                {
                    Name = "echo",
                    Description = "Echo",
                    Parameters = new JsonObject { ["type"] = "object" },
                },
            },
            ToolChoice = "auto",
            Temperature = 0.2,
        };

    private static void Check(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message);
        }
        _passed++;
    }

    private sealed class CaptureHandler : HttpMessageHandler
    {
        private readonly string _body;

        public CaptureHandler(string body)
        {
            _body = body;
        }

        public Dictionary<string, string> Headers { get; } = new(StringComparer.OrdinalIgnoreCase);

        public JsonObject? Body { get; private set; }

        protected override HttpResponseMessage Send(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            foreach (var header in request.Headers)
            {
                Headers[header.Key] = string.Join(",", header.Value);
            }
            var content = request.Content?.ReadAsStringAsync(cancellationToken)
                .GetAwaiter()
                .GetResult() ?? "{}";
            Body = Json.Parse(content) as JsonObject;
            var stream = Body?["stream"]?.GetValue<bool>() == true;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    _body,
                    Encoding.UTF8,
                    stream ? "text/event-stream" : "application/json"),
            };
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
            => Task.FromResult(Send(request, cancellationToken));
    }
}
