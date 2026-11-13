using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.McpExample;

public static class Program
{
    public static string Demo()
    {
        var transport = new InProcessTransport();
        using var client = new McpClient(transport);
        client.Connect();
        var tools = client.ListTools();
        client.RegisterTools(new ToolRegistry());
        var result = client.CallTool("add", new JsonObject
        {
            ["a"] = 2,
            ["b"] = 3,
        });
        var names = tools.Select(tool => tool.Name).OrderBy(name => name).ToList();
        return $"tools={string.Join(",", names)}; sum={result?["sum"]?.GetValue<int>()}";
    }

    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            var output = Demo();
            if (output != "tools=add,echo; sum=5")
            {
                Console.Error.WriteLine($"unexpected output: {output}");
                return 1;
            }
            Console.WriteLine("mcp test: ok");
            return 0;
        }
        Console.WriteLine(Demo());
        return 0;
    }

    private sealed class InProcessTransport : IMcpTransport
    {
        public int? ProcessId => Environment.ProcessId;

        public bool HasExited => false;

        public void Start()
        {
        }

        public void Send(JsonObject message)
        {
        }

        public void Notify(string method, JsonObject? parameters)
        {
        }

        public JsonObject Request(
            string method,
            JsonObject? parameters,
            TimeSpan timeout,
            CancellationToken cancellationToken)
        {
            return method switch
            {
                "initialize" => Envelope(new JsonObject
                {
                    ["protocolVersion"] = "2024-11-05",
                    ["capabilities"] = new JsonObject { ["tools"] = new JsonObject() },
                    ["serverInfo"] = new JsonObject
                    {
                        ["name"] = "example-mcp",
                        ["version"] = "1.0.0",
                    },
                }),
                "tools/list" => Envelope(new JsonObject { ["tools"] = Tools() }),
                "tools/call" => Envelope(CallTool(parameters)),
                _ => new JsonObject
                {
                    ["error"] = new JsonObject
                    {
                        ["code"] = -32601,
                        ["message"] = "method not found",
                    },
                },
            };
        }

        public void Close()
        {
        }

        public void Dispose()
        {
        }

        private static JsonObject Envelope(JsonObject result)
            => new() { ["result"] = result };

        private static JsonArray Tools() => new()
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
                        ["text"] = new JsonObject { ["type"] = "string" },
                    },
                    ["required"] = new JsonArray { "text" },
                },
            },
            new JsonObject
            {
                ["name"] = "add",
                ["description"] = "Add two integers",
                ["inputSchema"] = new JsonObject
                {
                    ["type"] = "object",
                    ["properties"] = new JsonObject
                    {
                        ["a"] = new JsonObject { ["type"] = "integer" },
                        ["b"] = new JsonObject { ["type"] = "integer" },
                    },
                    ["required"] = new JsonArray { "a", "b" },
                },
            },
        };

        private static JsonObject CallTool(JsonObject? parameters)
        {
            var name = parameters?["name"]?.GetValue<string>();
            var arguments = parameters?["arguments"] as JsonObject ?? new JsonObject();
            if (name == "echo")
            {
                return new JsonObject
                {
                    ["content"] = new JsonArray
                    {
                        new JsonObject
                        {
                            ["type"] = "text",
                            ["text"] = arguments["text"]?.GetValue<string>() ?? "",
                        },
                    },
                    ["isError"] = false,
                };
            }
            if (name == "add")
            {
                var sum = (arguments["a"]?.GetValue<int>() ?? 0)
                    + (arguments["b"]?.GetValue<int>() ?? 0);
                return new JsonObject
                {
                    ["content"] = new JsonArray
                    {
                        new JsonObject
                        {
                            ["type"] = "text",
                            ["text"] = sum.ToString(),
                        },
                    },
                    ["structuredContent"] = new JsonObject { ["sum"] = sum },
                    ["isError"] = false,
                };
            }
            return new JsonObject
            {
                ["content"] = new JsonArray
                {
                    new JsonObject
                    {
                        ["type"] = "text",
                        ["text"] = $"unknown tool {name}",
                    },
                },
                ["isError"] = true,
            };
        }
    }
}
