using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.ServiceExample;

public static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            RunDeterministicTest();
            Console.WriteLine("service test: ok");
            return 0;
        }

        var model = new OpenAiCompatibleModel(new HttpClient(), new OpenAiCompatibleOptions
        {
            BaseUrl = EnvOr("PRAXO_BASE_URL", "http://localhost:11434/v1"),
            ApiKey = Environment.GetEnvironmentVariable("PRAXO_API_KEY") ?? "",
            Model = EnvOr("PRAXO_MODEL", "llama3.2"),
        });
        Serve("127.0.0.1", 8080, CreateAgent(model), EnvOr("PRAXO_TENANT", "local"));
        return 0;
    }

    public static Agent CreateAgent(IModel model)
    {
        var tools = new ToolRegistry();
        tools.Register(new FuncTool(
            "get_time",
            "Return the current UTC time in ISO 8601 format.",
            _ => JsonValue.Create(DateTimeOffset.UtcNow.ToString("O"))));
        return new Agent(new AgentOptions(model)
        {
            Tools = tools,
            SystemPrompt = "You are a concise service assistant. Use tools when they help.",
            MaxSteps = 4,
            AllowedTools = new List<string> { "get_time" },
            Policy = new ServicePolicy(),
        });
    }

    public static (int Status, JsonObject Body) HandleRequest(
        Agent agent,
        string tenant,
        string method,
        string path,
        string? principal,
        string body)
    {
        if (method == "GET" && path == "/healthz")
        {
            return (200, new JsonObject { ["status"] = "ok" });
        }
        if (method != "POST" || path != "/run")
        {
            return (404, new JsonObject { ["error"] = "not found" });
        }
        if (string.IsNullOrEmpty(principal))
        {
            return (401, new JsonObject { ["error"] = "missing X-Praxo-Principal" });
        }
        JsonObject payload;
        try
        {
            payload = JsonNode.Parse(body) as JsonObject
                ?? throw new FormatException("body must be an object");
        }
        catch (Exception)
        {
            return (400, new JsonObject { ["error"] = "invalid JSON body" });
        }
        var prompt = payload["prompt"]?.GetValue<string>() ?? "";
        if (prompt.Length == 0)
        {
            return (400, new JsonObject { ["error"] = "prompt is required" });
        }
        try
        {
            var result = agent.Run(new Session(principal)
            {
                TenantId = tenant,
                WorkspaceId = "service",
            }, prompt);
            return (200, new JsonObject { ["output"] = result.Output });
        }
        catch (Exception error)
        {
            return (500, new JsonObject { ["error"] = error.Message });
        }
    }

    private static void RunDeterministicTest()
    {
        var agent = CreateAgent(new FakeModel());
        var health = HandleRequest(agent, "local", "GET", "/healthz", null, "");
        if (health.Status != 200)
        {
            throw new InvalidOperationException("health check failed");
        }
        var unauthorized = HandleRequest(agent, "local", "POST", "/run", null, "{\"prompt\":\"hi\"}");
        if (unauthorized.Status != 401)
        {
            throw new InvalidOperationException("missing principal was accepted");
        }
        var invalid = HandleRequest(agent, "local", "POST", "/run", "user-1", "not json");
        if (invalid.Status != 400)
        {
            throw new InvalidOperationException("invalid body was accepted");
        }
        var ok = HandleRequest(
            agent, "local", "POST", "/run", "user-1", "{\"prompt\":\"hi\"}");
        if (ok.Status != 200 || ok.Body["output"]?.GetValue<string>() != "hello from the service")
        {
            throw new InvalidOperationException("run path failed");
        }
    }

    private static void Serve(string host, int port, Agent agent, string tenant)
    {
        var listener = new TcpListener(IPAddress.Parse(host), port);
        listener.Start();
        Console.WriteLine($"listening on http://{host}:{port}");
        while (true)
        {
            var client = listener.AcceptTcpClient();
            ThreadPool.QueueUserWorkItem(_ => ServeClient(client, agent, tenant));
        }
    }

    private static void ServeClient(TcpClient client, Agent agent, string tenant)
    {
        using (client)
        using (var stream = client.GetStream())
        {
            try
            {
                var headers = ReadHeaders(stream, out var remainder);
                var lines = headers.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);
                if (lines.Length == 0)
                {
                    return;
                }
                var requestLine = lines[0].Split(' ');
                var method = requestLine[0];
                var path = requestLine[1];
                var headersByName = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                foreach (var line in lines.Skip(1))
                {
                    var colon = line.IndexOf(':');
                    if (colon > 0)
                    {
                        headersByName[line[..colon].Trim()] = line[(colon + 1)..].Trim();
                    }
                }
                var length = headersByName.TryGetValue("Content-Length", out var value)
                    && int.TryParse(value, out var parsed) ? parsed : 0;
                var body = ReadBody(stream, remainder, length);
                var principal = headersByName.GetValueOrDefault("X-Praxo-Principal");
                var (status, response) = HandleRequest(agent, tenant, method, path, principal, body);
                WriteResponse(stream, status, response);
            }
            catch (Exception)
            {
                WriteResponse(stream, 500, new JsonObject { ["error"] = "internal error" });
            }
        }
    }

    private static string ReadHeaders(NetworkStream stream, out byte[] remainder)
    {
        var buffer = new List<byte>();
        var single = new byte[1];
        while (buffer.Count < 65536)
        {
            var read = stream.Read(single, 0, 1);
            if (read == 0)
            {
                break;
            }
            buffer.Add(single[0]);
            if (buffer.Count >= 4
                && buffer[buffer.Count - 4] == (byte)'\r'
                && buffer[buffer.Count - 3] == (byte)'\n'
                && buffer[buffer.Count - 2] == (byte)'\r'
                && buffer[buffer.Count - 1] == (byte)'\n')
            {
                break;
            }
        }
        remainder = Array.Empty<byte>();
        return Encoding.ASCII.GetString(buffer.ToArray());
    }

    private static string ReadBody(NetworkStream stream, byte[] remainder, int length)
    {
        var body = new List<byte>(remainder);
        var buffer = new byte[4096];
        while (body.Count < length)
        {
            var read = stream.Read(buffer, 0, Math.Min(buffer.Length, length - body.Count));
            if (read == 0)
            {
                break;
            }
            body.AddRange(buffer.AsSpan(0, read).ToArray());
        }
        return Encoding.UTF8.GetString(body.ToArray());
    }

    private static void WriteResponse(NetworkStream stream, int status, JsonObject body)
    {
        var encoded = Encoding.UTF8.GetBytes(body.ToJsonString());
        var reason = status switch
        {
            200 => "OK",
            400 => "Bad Request",
            401 => "Unauthorized",
            404 => "Not Found",
            _ => "Internal Server Error",
        };
        var header = Encoding.ASCII.GetBytes(
            $"HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\n" +
            $"Content-Length: {encoded.Length}\r\nConnection: close\r\n\r\n");
        stream.Write(header);
        stream.Write(encoded);
    }

    private static string EnvOr(string name, string fallback)
        => string.IsNullOrEmpty(Environment.GetEnvironmentVariable(name))
            ? fallback
            : Environment.GetEnvironmentVariable(name)!;

    private sealed class ServicePolicy : IPolicyHook
    {
        public Decision Authorize(Praxo.Core.Action action)
            => action.Kind switch
            {
                "model.generate" => Decision.Allow("model generation"),
                "tool.invoke" when action.ToolName == "get_time" =>
                    Decision.Allow("get_time is permitted"),
                "tool.invoke" => Decision.Deny("only get_time is permitted"),
                _ => Decision.Deny("unsupported action"),
            };
    }

    private sealed class FakeModel : IModel
    {
        public Response Generate(Request request)
            => new() { Message = Message.Assistant("hello from the service") };
    }
}
