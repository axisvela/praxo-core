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
        if (args.Length > 1 && args[0] == "--revoke-token")
        {
            var revokeUrl = Environment.GetEnvironmentVariable("PRAXO_REVOCATION_URL") ?? "";
            if (revokeUrl.Length == 0)
            {
                Console.Error.WriteLine("PRAXO_REVOCATION_URL is required");
                return 1;
            }
            RevocationClient.RevokeAsync(
                args[1],
                new HttpClient { Timeout = AuthTimeout() },
                revokeUrl,
                EnvOr("PRAXO_INTROSPECTION_CLIENT_ID",
                    Environment.GetEnvironmentVariable("PRAXO_OIDC_CLIENT_ID") ?? ""),
                EnvOr("PRAXO_INTROSPECTION_CLIENT_SECRET",
                    Environment.GetEnvironmentVariable("PRAXO_OIDC_CLIENT_SECRET") ?? ""))
                .GetAwaiter().GetResult();
            Console.WriteLine("token revoked");
            return 0;
        }

        var tenant = EnvOr("PRAXO_TENANT", "local");
        var model = new OpenAiCompatibleModel(new HttpClient(), new OpenAiCompatibleOptions
        {
            BaseUrl = EnvOr("PRAXO_BASE_URL", "http://localhost:11434/v1"),
            ApiKey = Environment.GetEnvironmentVariable("PRAXO_API_KEY") ?? "",
            Model = EnvOr("PRAXO_MODEL", "llama3.2"),
        });
        Serve("127.0.0.1", 8080, CreateAgent(model), CreateAuthenticator(tenant));
        return 0;
    }

    private static IRequestAuthenticator CreateAuthenticator(string tenant)
    {
        var url = Environment.GetEnvironmentVariable("PRAXO_INTROSPECTION_URL") ?? "";
        if (url.Length > 0)
        {
            return new IntrospectionAuthenticator(
                new HttpClient { Timeout = AuthTimeout() },
                url,
                EnvOr("PRAXO_INTROSPECTION_CLIENT_ID",
                    Environment.GetEnvironmentVariable("PRAXO_OIDC_CLIENT_ID") ?? ""),
                EnvOr("PRAXO_INTROSPECTION_CLIENT_SECRET",
                    Environment.GetEnvironmentVariable("PRAXO_OIDC_CLIENT_SECRET") ?? ""),
                EnvOr("PRAXO_OIDC_TENANT_CLAIM", "tenant"));
        }
        return new ContextAuthenticator(tenant);
    }

    private static TimeSpan AuthTimeout()
    {
        var raw = Environment.GetEnvironmentVariable("PRAXO_OIDC_TIMEOUT") ?? "";
        return short.TryParse(raw, out var seconds) && seconds > 0
            ? TimeSpan.FromSeconds(seconds)
            : TimeSpan.FromSeconds(2);
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
        RunIntrospectionTests();
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

    private static void RunIntrospectionTests()
    {
        var now = DateTimeOffset.UtcNow;
        var expires = now.AddMinutes(1).ToUnixTimeSeconds();
        var active = new IntrospectionAuthenticator(
            new HttpClient(new FakeHandler(_ => JsonResponse(
                $$"""{"active":true,"sub":"user-1","tenant":"local","exp":{{expires}}}"""))),
            "https://id.example.com/introspect", "", "", "tenant");
        var principal = active.Authenticate(null, "Bearer opaque", now);
        if (principal is null
            || principal.Subject != "user-1"
            || principal.Tenant != "local")
        {
            throw new InvalidOperationException("introspection active path failed");
        }

        var inactive = new IntrospectionAuthenticator(
            new HttpClient(new FakeHandler(_ => JsonResponse("""{"active":false}"""))),
            "https://id.example.com/introspect", "", "", "tenant");
        if (inactive.Authenticate(null, "Bearer opaque", now) is not null)
        {
            throw new InvalidOperationException("inactive token was accepted");
        }

        var missingExp = new IntrospectionAuthenticator(
            new HttpClient(new FakeHandler(_ => JsonResponse(
                """{"active":true,"sub":"user-1","tenant":"local"}"""))),
            "https://id.example.com/introspect", "", "", "tenant");
        if (missingExp.Authenticate(null, "Bearer opaque", now) is not null)
        {
            throw new InvalidOperationException("missing expiration was accepted");
        }

        var unavailable = new IntrospectionAuthenticator(
            new HttpClient(new FakeHandler(_ => new HttpResponseMessage(
                HttpStatusCode.ServiceUnavailable))),
            "https://id.example.com/introspect", "", "", "tenant");
        if (unavailable.Authenticate(null, "Bearer opaque", now) is not null)
        {
            throw new InvalidOperationException("unavailable provider was accepted");
        }

        RevocationClient.RevokeAsync(
            "opaque",
            new HttpClient(new FakeHandler(_ => new HttpResponseMessage(HttpStatusCode.OK))),
            "https://id.example.com/revoke", "", "").GetAwaiter().GetResult();
        try
        {
            RevocationClient.RevokeAsync(
                "opaque",
                new HttpClient(new FakeHandler(_ => new HttpResponseMessage(
                    HttpStatusCode.ServiceUnavailable))),
                "https://id.example.com/revoke", "", "").GetAwaiter().GetResult();
            throw new InvalidOperationException("revocation failure was accepted");
        }
        catch (InvalidOperationException error)
            when (error.Message == "token revocation failed")
        {
        }
    }

    private static HttpResponseMessage JsonResponse(string json)
        => new(HttpStatusCode.OK)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json"),
        };

    private static void Serve(
        string host,
        int port,
        Agent agent,
        IRequestAuthenticator authenticator)
    {
        var listener = new TcpListener(IPAddress.Parse(host), port);
        listener.Start();
        Console.WriteLine($"listening on http://{host}:{port}");
        while (true)
        {
            var client = listener.AcceptTcpClient();
            ThreadPool.QueueUserWorkItem(_ => ServeClient(client, agent, authenticator));
        }
    }

    private static void ServeClient(
        TcpClient client,
        Agent agent,
        IRequestAuthenticator authenticator)
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
                var principalHeader = headersByName.GetValueOrDefault("X-Praxo-Principal");
                var authorization = headersByName.GetValueOrDefault("Authorization");
                var principal = authenticator.Authenticate(
                    principalHeader, authorization, DateTimeOffset.UtcNow);
                if (principal is null)
                {
                    WriteResponse(stream, 401, new JsonObject { ["error"] = "unauthorized" });
                    return;
                }
                var (status, response) = HandleRequest(
                    agent, principal.Tenant, method, path, principal.Subject, body);
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

    private sealed class FakeHandler : HttpMessageHandler
    {
        private readonly Func<HttpRequestMessage, HttpResponseMessage> _handler;

        public FakeHandler(Func<HttpRequestMessage, HttpResponseMessage> handler)
        {
            _handler = handler;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
            => Task.FromResult(_handler(request));
    }
}
