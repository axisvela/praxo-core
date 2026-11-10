using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tests;

internal static class FakeMcpServer
{
    public const string ProtocolVersion = "2024-11-05";

    public static int Run(string[] args)
    {
        var mode = Value(args, "--mode") ?? "default";
        var marker = Value(args, "--marker");
        var initialized = false;
        while (true)
        {
            var line = Console.In.ReadLine();
            if (line == null)
            {
                Mark(marker, "exit");
                return 0;
            }
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }
            JsonObject message;
            try
            {
                if (!Json.TryParseObject(line, out message))
                {
                    continue;
                }
            }
            catch (Exception)
            {
                continue;
            }
            var method = Json.GetString(message, "method");
            var id = message["id"];
            switch (method)
            {
                case "initialize":
                    Respond(id, new JsonObject
                    {
                        ["protocolVersion"] = ProtocolVersion,
                        ["capabilities"] = new JsonObject
                        {
                            ["tools"] = new JsonObject(),
                        },
                        ["serverInfo"] = new JsonObject
                        {
                            ["name"] = "fake-mcp",
                            ["version"] = "1.0.0",
                        },
                    });
                    break;
                case "notifications/initialized":
                    initialized = true;
                    Mark(marker, "initialized");
                    break;
                case "notifications/cancelled":
                    Mark(marker, "cancelled");
                    break;
                case "tools/list":
                    if (!initialized)
                    {
                        Error(id, -32002, "not initialized");
                        break;
                    }
                    Respond(id, ListTools(mode, Json.GetString(message["params"], "cursor")));
                    break;
                case "tools/call":
                    if (!initialized)
                    {
                        Error(id, -32002, "not initialized");
                        break;
                    }
                    Mark(marker, $"call:{Json.GetString(message["params"], "name")}");
                    if (mode == "hang")
                    {
                        Mark(marker, "hanging");
                        break;
                    }
                    Respond(id, CallTool(message["params"]));
                    break;
                default:
                    if (id != null)
                    {
                        Error(id, -32601, "method not found");
                    }
                    break;
            }
        }
    }

    private static JsonObject ListTools(string mode, string? cursor)
    {
        if (mode == "repeated-cursor")
        {
            return new JsonObject
            {
                ["tools"] = new JsonArray { GenericTool(cursor == null ? "loop-start" : "loop-more") },
                ["nextCursor"] = "loop",
            };
        }
        if (mode == "duplicate-name")
        {
            if (cursor == null)
            {
                return new JsonObject
                {
                    ["tools"] = new JsonArray { GenericTool("dup") },
                    ["nextCursor"] = "page-2",
                };
            }
            return new JsonObject
            {
                ["tools"] = new JsonArray { GenericTool("dup") },
            };
        }
        if (cursor == null)
        {
            return new JsonObject
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
                                ["text"] = new JsonObject { ["type"] = "string" },
                            },
                            ["required"] = new JsonArray { "text" },
                        },
                    },
                    GenericTool("add"),
                },
                ["nextCursor"] = "page-2",
            };
        }
        if (cursor == "page-2")
        {
            return new JsonObject
            {
                ["tools"] = new JsonArray { GenericTool("fail"), GenericTool("multi") },
            };
        }
        return new JsonObject { ["tools"] = new JsonArray() };
    }

    private static JsonObject CallTool(JsonNode? parameters)
    {
        var name = Json.GetString(parameters, "name");
        var arguments = Json.Object(parameters?["arguments"]);
        switch (name)
        {
            case "echo":
                return new JsonObject
                {
                    ["content"] = new JsonArray
                    {
                        new JsonObject
                        {
                            ["type"] = "text",
                            ["text"] = Json.GetString(arguments, "text") ?? "",
                        },
                    },
                };
            case "add":
            {
                var sum = Json.GetInt(arguments, "a") + Json.GetInt(arguments, "b");
                return new JsonObject
                {
                    ["content"] = new JsonArray
                    {
                        new JsonObject { ["type"] = "text", ["text"] = sum.ToString() },
                    },
                    ["structuredContent"] = new JsonObject { ["sum"] = sum },
                };
            }
            case "multi":
                return new JsonObject
                {
                    ["content"] = new JsonArray
                    {
                        new JsonObject { ["type"] = "text", ["text"] = "one" },
                        new JsonObject { ["type"] = "text", ["text"] = "two" },
                    },
                };
            case "fail":
                return new JsonObject
                {
                    ["isError"] = true,
                    ["content"] = new JsonArray
                    {
                        new JsonObject { ["type"] = "text", ["text"] = "boom" },
                    },
                };
            default:
                return new JsonObject
                {
                    ["isError"] = true,
                    ["content"] = new JsonArray
                    {
                        new JsonObject
                        {
                            ["type"] = "text",
                            ["text"] = $"unknown tool {name}",
                        },
                    },
                };
        }
    }

    private static JsonObject GenericTool(string name)
        => new()
        {
            ["name"] = name,
            ["description"] = "generic",
            ["inputSchema"] = new JsonObject
            {
                ["type"] = "object",
                ["properties"] = new JsonObject(),
            },
        };

    private static string? Value(string[] args, string name)
    {
        var index = Array.IndexOf(args, name);
        return index >= 0 && index + 1 < args.Length ? args[index + 1] : null;
    }

    private static void Mark(string? marker, string line)
    {
        if (string.IsNullOrEmpty(marker))
        {
            return;
        }
        for (var attempt = 0; attempt < 20; attempt++)
        {
            try
            {
                using var stream = new FileStream(
                    marker,
                    FileMode.Append,
                    FileAccess.Write,
                    FileShare.ReadWrite | FileShare.Delete);
                using var writer = new StreamWriter(stream);
                writer.WriteLine(line);
                writer.Flush();
                return;
            }
            catch (IOException)
            {
                Thread.Sleep(5);
            }
            catch (UnauthorizedAccessException)
            {
                return;
            }
        }
    }

    private static void Respond(JsonNode? id, JsonObject result)
    {
        Write(new JsonObject
        {
            ["jsonrpc"] = "2.0",
            ["id"] = id?.DeepClone(),
            ["result"] = result,
        });
    }

    private static void Error(JsonNode? id, int code, string message)
    {
        Write(new JsonObject
        {
            ["jsonrpc"] = "2.0",
            ["id"] = id?.DeepClone(),
            ["error"] = new JsonObject
            {
                ["code"] = code,
                ["message"] = message,
            },
        });
    }

    private static void Write(JsonObject message)
    {
        Console.Out.WriteLine(Json.Stringify(message));
        Console.Out.Flush();
    }
}
