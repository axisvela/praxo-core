using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tests;

internal static class McpHttpTests
{
    private static int _passed;

    public static int Run()
    {
        _passed = 0;
        TestHandshakeListCallAndDelete();
        TestSseResponse();
        TestRejectsRemotePlainHttp();
        return _passed;
    }

    private static void TestHandshakeListCallAndDelete()
    {
        var handler = new FakeHandler();
        using var http = new HttpClient(handler);
        var transport = new McpStreamableHttpTransport(
            new McpStreamableHttpOptions
            {
                Endpoint = "http://127.0.0.1/mcp",
                HttpClient = http,
            });
        using var client = new McpClient(
            transport, null, "praxo-core", "0.5.0", "2025-03-26");
        client.Connect();
        Check(client.ProtocolVersion == "2025-03-26", "http protocol version");
        var tools = client.ListTools();
        Check(tools.Select(tool => tool.Name).SequenceEqual(new[] { "echo" }),
            "http tool names");
        var result = client.CallTool("echo", new JsonObject { ["text"] = "hi" });
        Check(result?.GetValue<string>() == "http-ok", "http tool result");
        client.Close();
        Check(handler.Deleted, "http delete");
        var listed = handler.Requests
            .First(item => item.Body.Contains("\"tools/list\""));
        Check(listed.Headers.TryGetValue("mcp-session-id", out var session)
            && session == "sess-1", "http session header");
        Check(listed.Headers.TryGetValue("mcp-protocol-version", out var version)
            && version == "2025-03-26", "http protocol header");
    }

    private static void TestSseResponse()
    {
        var handler = new FakeHandler { Sse = true };
        using var http = new HttpClient(handler);
        using var client = new McpClient(
            new McpStreamableHttpTransport(
                new McpStreamableHttpOptions
                {
                    Endpoint = "http://127.0.0.1/mcp",
                    HttpClient = http,
                }),
            null,
            "praxo-core",
            "0.5.0",
            "2025-03-26");
        client.Connect();
        var result = client.CallTool("echo", new JsonObject { ["text"] = "hi" });
        Check(result?.GetValue<string>() == "sse-ok", "http sse result");
    }

    private static void TestRejectsRemotePlainHttp()
    {
        var rejected = false;
        try
        {
            _ = new McpStreamableHttpTransport(
                new McpStreamableHttpOptions
                {
                    Endpoint = "http://example.com/mcp",
                });
        }
        catch (PraxoException error) when (error.Code == "MCP_TRANSPORT")
        {
            rejected = true;
        }
        Check(rejected, "http remote plain http rejected");
    }

    private sealed class FakeHandler : HttpMessageHandler
    {
        public List<(HttpMethod Method, string Body, Dictionary<string, string> Headers)>
            Requests { get; } = new();

        public bool Sse { get; set; }

        public bool Deleted { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            try
            {
                return Task.FromResult(SendCore(request, cancellationToken));
            }
            catch (Exception error)
            {
                return Task.FromException<HttpResponseMessage>(error);
            }
        }

        private HttpResponseMessage SendCore(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            if (request.Method == HttpMethod.Delete)
            {
                Deleted = true;
                return new HttpResponseMessage(HttpStatusCode.OK);
            }
            var headers = request.Headers.ToDictionary(
                item => item.Key.ToLowerInvariant(),
                item => string.Join(",", item.Value));
            var body = request.Content?
                .ReadAsStringAsync(cancellationToken)
                .GetAwaiter()
                .GetResult() ?? "";
            Requests.Add((request.Method, body, headers));
            var message = JsonNode.Parse(body)!.AsObject();
            var method = message["method"]?.GetValue<string>() ?? "";
            if (method == "initialize")
            {
                var response = Json(new JsonObject
                {
                    ["jsonrpc"] = "2.0",
                    ["id"] = message["id"]?.DeepClone(),
                    ["result"] = new JsonObject
                    {
                        ["protocolVersion"] = "2025-03-26",
                        ["capabilities"] = new JsonObject(),
                        ["serverInfo"] = new JsonObject
                        {
                            ["name"] = "fake-http",
                            ["version"] = "1",
                        },
                    },
                });
                response.Headers.TryAddWithoutValidation("mcp-session-id", "sess-1");
                return response;
            }
            if (method.StartsWith("notifications/", StringComparison.Ordinal))
            {
                return new HttpResponseMessage(HttpStatusCode.Accepted);
            }
            if (method == "tools/list")
            {
                return Json(new JsonObject
                {
                    ["jsonrpc"] = "2.0",
                    ["id"] = message["id"]?.DeepClone(),
                    ["result"] = new JsonObject
                    {
                        ["tools"] = new JsonArray
                        {
                            new JsonObject
                            {
                                ["name"] = "echo",
                                ["description"] = "Echo input",
                                ["inputSchema"] = new JsonObject
                                {
                                    ["type"] = "object",
                                    ["properties"] = new JsonObject
                                    {
                                        ["text"] = new JsonObject
                                        {
                                            ["type"] = "string",
                                        },
                                    },
                                },
                            },
                        },
                    },
                });
            }
            if (method == "tools/call")
            {
                var result = new JsonObject
                {
                    ["jsonrpc"] = "2.0",
                    ["id"] = message["id"]?.DeepClone(),
                    ["result"] = new JsonObject
                    {
                        ["content"] = new JsonArray
                        {
                            new JsonObject
                            {
                                ["type"] = "text",
                                ["text"] = Sse ? "sse-ok" : "http-ok",
                            },
                        },
                    },
                };
                if (Sse)
                {
                    return new HttpResponseMessage(HttpStatusCode.OK)
                    {
                        Content = new StringContent(
                            $"event: message\ndata: {result.ToJsonString()}\n\n",
                            Encoding.UTF8,
                            "text/event-stream"),
                    };
                }
                return Json(result);
            }
            return Json(new JsonObject
            {
                ["jsonrpc"] = "2.0",
                ["id"] = message["id"]?.DeepClone(),
                ["result"] = new JsonObject(),
            });
        }

        private static HttpResponseMessage Json(JsonObject body)
        {
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    body.ToJsonString(), Encoding.UTF8, "application/json"),
            };
        }
    }

    private static void Check(bool condition, string name)
    {
        if (!condition)
        {
            throw new InvalidOperationException($"check failed: {name}");
        }
        _passed++;
    }
}
