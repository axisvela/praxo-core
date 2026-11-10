using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tests;

internal static class McpTests
{
    private static int _passed;

    public static int Run()
    {
        _passed = 0;
        TestHandshakeAndTools();
        TestRepeatedCursor();
        TestDuplicateName();
        TestCallAndErrors();
        TestTimeoutAndCleanup();
        return _passed;
    }

    private static void TestHandshakeAndTools()
    {
        using var client = new McpClient(McpServer("default"));
        client.Connect();
        Check(client.Connected, "mcp connected");
        Check(client.ProtocolVersion == FakeMcpServer.ProtocolVersion, "mcp protocol version");
        Check(client.ServerInfo["name"]?.GetValue<string>() == "fake-mcp", "mcp server info");
        var tools = client.ListTools();
        Check(tools.Select(tool => tool.Name)
            .SequenceEqual(new[] { "add", "echo", "fail", "multi" }), "mcp tool names");
        var echo = tools.First(tool => tool.Name == "echo");
        Check(echo.Description == "Echo input", "mcp tool description");
        Check(echo.InputSchema["type"]?.GetValue<string>() == "object", "mcp input schema");
        var properties = echo.InputSchema["properties"] as JsonObject;
        Check(properties?["text"]?["type"]?.GetValue<string>() == "string", "mcp schema property");
        var required = echo.InputSchema["required"] as JsonArray;
        Check(required != null && required.Count == 1
            && required[0]?.GetValue<string>() == "text", "mcp schema required");

        var registry = new ToolRegistry();
        var adapters = client.RegisterTools(registry);
        Check(adapters.Count == 4 && registry.Count == 4, "mcp register tools");
        var spec = registry.Specs().First(item => item.Name == "echo");
        Check(spec.Parameters?["type"]?.GetValue<string>() == "object", "mcp registry schema");
        Check(spec.Parameters?["properties"]?["text"]?["type"]?.GetValue<string>() == "string",
            "mcp registry property schema");
    }

    private static void TestRepeatedCursor()
    {
        using var client = new McpClient(McpServer("repeated-cursor"));
        client.Connect();
        var rejected = false;
        try
        {
            client.ListTools();
        }
        catch (PraxoException error) when (error.Code == "MCP_PAGINATION")
        {
            rejected = true;
        }
        Check(rejected, "mcp repeated cursor rejected");
    }

    private static void TestDuplicateName()
    {
        using var client = new McpClient(McpServer("duplicate-name"));
        client.Connect();
        var rejected = false;
        try
        {
            client.ListTools();
        }
        catch (PraxoException error) when (error.Code == "MCP_DUPLICATE_TOOL")
        {
            rejected = true;
        }
        Check(rejected, "mcp duplicate name rejected");
    }

    private static void TestCallAndErrors()
    {
        using var client = new McpClient(McpServer("default"));
        client.Connect();
        var echo = client.CallTool("echo", new JsonObject { ["text"] = "hello" });
        Check(echo?.GetValue<string>() == "hello", "mcp text content");
        var add = client.CallTool("add", new JsonObject { ["a"] = 1, ["b"] = 2 });
        Check(add is JsonObject structured && structured["sum"]?.GetValue<int>() == 3,
            "mcp structured content");
        var multi = client.CallTool("multi") as JsonArray;
        Check(multi != null && multi.Count == 2
            && multi[0]?.GetValue<string>() == "one"
            && multi[1]?.GetValue<string>() == "two", "mcp multiple text content");
        var failed = false;
        try
        {
            client.CallTool("fail");
        }
        catch (PraxoException error) when (error.Code == "MCP_TOOL_ERROR")
        {
            failed = error.Message.Contains("boom", StringComparison.Ordinal);
        }
        Check(failed, "mcp tool error");
    }

    private static void TestTimeoutAndCleanup()
    {
        var marker = Path.Combine(
            Path.GetTempPath(),
            $"praxo-mcp-{Guid.NewGuid():N}.log");
        var transport = new McpStdioTransport(McpServer("hang", marker));
        using var client = new McpClient(transport, TimeSpan.FromSeconds(5));
        client.Connect();
        var timedOut = false;
        try
        {
            client.CallTool("hang", null, TimeSpan.FromMilliseconds(100));
        }
        catch (PraxoException error) when (error.Code == "MCP_TIMEOUT")
        {
            timedOut = true;
        }
        Check(timedOut, "mcp timeout");
        Check(WaitForMarker(marker, "cancelled"), "mcp cancellation notification");
        client.Close();
        Check(WaitForMarker(marker, "exit"), "mcp process cleanup");
        Check(transport.HasExited, "mcp transport exited");
        try
        {
            File.Delete(marker);
        }
        catch (IOException)
        {
        }
    }

    private static McpServerOptions McpServer(string mode, string? marker = null)
    {
        var assembly = typeof(Program).Assembly.Location;
        var process = Environment.ProcessPath
            ?? throw new InvalidOperationException("process path is unavailable");
        var options = new McpServerOptions();
        var name = Path.GetFileNameWithoutExtension(process);
        if (string.Equals(name, "dotnet", StringComparison.OrdinalIgnoreCase))
        {
            options.Command = process;
            options.Args.Add(assembly);
        }
        else
        {
            options.Command = process;
        }
        options.Args.Add("--fake-mcp-server");
        options.Args.Add("--mode");
        options.Args.Add(mode);
        if (marker != null)
        {
            options.Args.Add("--marker");
            options.Args.Add(marker);
        }
        return options;
    }

    private static bool WaitForMarker(string path, string text)
    {
        var deadline = DateTime.UtcNow.AddSeconds(5);
        while (DateTime.UtcNow < deadline)
        {
            try
            {
                if (File.Exists(path))
                {
                    using var stream = new FileStream(
                        path,
                        FileMode.Open,
                        FileAccess.Read,
                        FileShare.ReadWrite | FileShare.Delete);
                    using var reader = new StreamReader(stream);
                    if (reader.ReadToEnd().Contains(text, StringComparison.Ordinal))
                    {
                        return true;
                    }
                }
            }
            catch (IOException)
            {
            }
            Thread.Sleep(25);
        }
        return false;
    }

    private static void Check(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message);
        }
        _passed++;
    }
}
