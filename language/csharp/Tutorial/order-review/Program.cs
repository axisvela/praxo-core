using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.OrderReview;

public static class Program
{
    private sealed class FixtureModel(string orderId) : IModel
    {
        public Response Generate(Request request)
        {
            var last = request.Messages[^1];
            return new Response
            {
                Message = last.Role == Roles.Tool ? Message.Assistant(last.Content ?? "")
                    : Message.Assistant("", new[]
                    {
                        new ToolCall
                        {
                            Id = "review-1", Name = "review_order",
                            Arguments = new JsonObject { ["order_id"] = orderId },
                        },
                    }),
            };
        }
    }

    private sealed class OrderPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
            => action.Kind == "model.generate" || (action.Kind == "tool.invoke"
                && action.ToolName == "review_order"
                && action.Arguments?["order_id"]?.GetValue<string>() == "order-100")
                ? Decision.Allow("fixed order scope") : Decision.Deny("only order-100 is permitted");
    }

    private sealed class ReviewTool(HttpClient http, Uri origin, string token) : ITool, IToolSpecProvider
    {
        public string Name => "review_order";
        public string Description => "Read an order and create a service-desk draft, never a refund.";

        public ToolSpec Spec() => new()
        {
            Name = Name, Description = Description, Risk = "write",
            Parameters = JsonNode.Parse("""
                {"type":"object","required":["order_id"],"properties":{"order_id":{"type":"string"}}}
                """)!.AsObject(),
        };

        private JsonObject Request(string path, JsonObject? body = null)
        {
            using var request = new HttpRequestMessage(body is null ? HttpMethod.Get : HttpMethod.Post,
                new Uri(origin, path));
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            if (body is not null)
            {
                request.Headers.Add("Idempotency-Key", "csharp-review-1");
                request.Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json");
            }
            using var response = http.Send(request);
            if (!response.IsSuccessStatusCode)
                throw new HttpRequestException($"Business service rejected request: {(int)response.StatusCode}");
            return JsonNode.Parse(response.Content.ReadAsStringAsync().GetAwaiter().GetResult())?.AsObject()
                ?? throw new InvalidOperationException("Business service returned no object");
        }

        public JsonNode? Invoke(JsonObject arguments)
        {
            var order = Request($"/v1/orders/{arguments["order_id"]!.GetValue<string>()}");
            string recommendation = order["status"]?.GetValue<string>() == "delayed"
                ? "Contact carrier" : "Monitor shipment";
            var draft = Request($"/v1/orders/{order["id"]!.GetValue<string>()}/drafts",
                new JsonObject { ["recommendation"] = recommendation });
            return new JsonObject { ["order"] = order, ["draft"] = draft };
        }
    }

    public static string Review(HttpClient http, string baseUrl, string token, string orderId)
    {
        var origin = new Uri(baseUrl, UriKind.Absolute);
        if (origin.Scheme != "http" || !origin.IsLoopback || origin.AbsolutePath != "/"
            || origin.Query.Length != 0 || origin.Fragment.Length != 0 || origin.UserInfo.Length != 0)
            throw new ArgumentException("Expected a loopback HTTP business-service origin");
        var tools = new ToolRegistry();
        tools.Register(new ReviewTool(http, origin, token));
        var options = new AgentOptions(new FixtureModel(orderId))
        {
            Tools = tools, MaxSteps = 3, AllowedTools = new List<string> { "review_order" },
            Policy = new OrderPolicy(),
        };
        return new Agent(options).Run(new Session("order-review"), $"Review {orderId}; draft only.").Output;
    }

    public static WebApplication CreateApp(string baseUrl, string token, string url, HttpClient http)
    {
        var address = new Uri(url, UriKind.Absolute);
        if (address.Scheme != "http" || address.Host != "127.0.0.1" || address.AbsolutePath != "/"
            || address.Query.Length != 0 || address.Fragment.Length != 0 || address.UserInfo.Length != 0)
            throw new ArgumentException("Web entry must use http://127.0.0.1:<port>");
        var builder = WebApplication.CreateSlimBuilder();
        builder.Logging.ClearProviders();
        builder.WebHost.UseUrls(url);
        var app = builder.Build();
        app.MapGet("/healthz", () => Results.Text("{\"status\":\"ok\"}", "application/json"));
        app.MapPost("/review/order-100", (HttpContext context) =>
        {
            if (context.Request.Headers.Authorization.ToString() != "Bearer demo-a-token")
                return Results.Text("{\"error\":\"unauthenticated\"}", "application/json", statusCode: 401);
            try
            {
                return Results.Text(Review(http, baseUrl, token, "order-100"), "application/json");
            }
            catch (Exception)
            {
                return Results.Text("{\"error\":\"review_failed\"}", "application/json", statusCode: 503);
            }
        });
        return app;
    }

    public static async Task<int> Main(string[] args)
    {
        if (args.SequenceEqual(new[] { "--test" }))
        {
            await SelfTest.Run();
            return 0;
        }
        using var http = new HttpClient(new HttpClientHandler { UseProxy = false, AllowAutoRedirect = false })
        {
            Timeout = TimeSpan.FromSeconds(5), MaxResponseContentBufferSize = 16384,
        };
        string baseUrl = Environment.GetEnvironmentVariable("DEMO_BASE_URL") ?? "http://127.0.0.1:8765";
        string token = Environment.GetEnvironmentVariable("DEMO_TOKEN") ?? "demo-a-token";
        try
        {
            if (args.Length == 0)
                Console.WriteLine(Review(http, baseUrl, token,
                    Environment.GetEnvironmentVariable("DEMO_ORDER") ?? "order-100"));
            else if (args.SequenceEqual(new[] { "--serve" }))
            {
                await using var app = CreateApp(baseUrl, token,
                    Environment.GetEnvironmentVariable("DEMO_WEB_URL") ?? "http://127.0.0.1:8087", http);
                await app.RunAsync();
            }
            else throw new ArgumentException("Usage: dotnet Praxo.OrderReview.dll [--serve|--test]");
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error.Message);
            return 1;
        }
    }
}
