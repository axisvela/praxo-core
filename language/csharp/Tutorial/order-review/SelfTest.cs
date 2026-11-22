using System.Net;
using System.Net.Http.Headers;
using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.OrderReview;

internal static class SelfTest
{
    private sealed class Backend : HttpMessageHandler
    {
        public int Reads { get; private set; }
        public int Writes { get; private set; }
        public bool Available { get; set; } = true;

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromResult(Send(request, cancellationToken));

        protected override HttpResponseMessage Send(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (!Available) return new HttpResponseMessage(HttpStatusCode.ServiceUnavailable);
            if (request.Headers.Authorization?.ToString() != "Bearer demo-a-token")
                return new HttpResponseMessage(HttpStatusCode.Forbidden);
            string body;
            if (request.Method == HttpMethod.Get && request.RequestUri!.AbsolutePath == "/v1/orders/order-100")
            {
                Reads++;
                body = "{\"id\":\"order-100\",\"status\":\"delayed\"}";
            }
            else if (request.Method == HttpMethod.Post && request.RequestUri!.AbsolutePath == "/v1/orders/order-100/drafts")
            {
                Check(request.Headers.GetValues("Idempotency-Key").Single() == "csharp-review-1", "idempotency key");
                var input = JsonNode.Parse(request.Content!.ReadAsStringAsync().GetAwaiter().GetResult())!;
                Check(input["recommendation"]!.GetValue<string>() == "Contact carrier", "recommendation");
                Writes++;
                body = "{\"status\":\"draft_only\"}";
            }
            else throw new InvalidOperationException("Unexpected business request");
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(body) };
        }
    }

    private static void Check(bool condition, string name)
    {
        if (!condition) throw new InvalidOperationException($"Failed: {name}");
    }

    public static async Task Run()
    {
        var backend = new Backend();
        using var business = new HttpClient(backend) { Timeout = TimeSpan.FromSeconds(5) };
        const string origin = "http://127.0.0.1:8765";
        foreach (string invalidOrigin in new[] { "http://example.com", "http://127.0.0.1:8765/path" })
        {
            try
            {
                Program.Review(business, invalidOrigin, "demo-a-token", "order-100");
                throw new InvalidOperationException("Invalid business origin accepted");
            }
            catch (ArgumentException) { }
        }
        Check(backend.Reads == 0 && backend.Writes == 0, "invalid origin before HTTP");
        string output = Program.Review(business, origin, "demo-a-token", "order-100");
        Check(JsonNode.Parse(output)!["draft"]!["status"]!.GetValue<string>() == "draft_only", "native result");
        Check(backend.Reads == 1 && backend.Writes == 1, "native effect counts");
        try
        {
            Program.Review(business, origin, "demo-a-token", "order-200");
            throw new InvalidOperationException("Agent scope allowed order-200");
        }
        catch (PraxoException error) when (error.Code == "AGENT_POLICY_DENIED") { }
        Check(backend.Reads == 1 && backend.Writes == 1, "Agent denial before HTTP");

        await using var app = Program.CreateApp(origin, "demo-a-token", "http://127.0.0.1:0", business);
        await app.StartAsync();
        try
        {
            using var client = new HttpClient(new HttpClientHandler { UseProxy = false })
            {
                BaseAddress = new Uri(app.Urls.Single()), Timeout = TimeSpan.FromSeconds(10),
            };
            using var denied = await client.PostAsync("/review/order-100", null);
            Check(denied.StatusCode == HttpStatusCode.Unauthorized, "Web authentication");
            Check(backend.Writes == 1, "unauthenticated zero effects");
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "demo-a-token");
            using var allowed = await client.PostAsync("/review/order-100", null);
            Check(allowed.StatusCode == HttpStatusCode.OK, "Web allow");
            var payload = JsonNode.Parse(await allowed.Content.ReadAsStringAsync())!;
            Check(payload["draft"]!["status"]!.GetValue<string>() == "draft_only", "Web result JSON");
            Check(backend.Writes == 2, "Web draft created");
            using var unknown = await client.PostAsync("/review/order-200", null);
            Check(unknown.StatusCode == HttpStatusCode.NotFound && backend.Writes == 2, "Web route scope");
            backend.Available = false;
            using var failed = await client.PostAsync("/review/order-100", null);
            Check(failed.StatusCode == HttpStatusCode.ServiceUnavailable, "dependency fails closed");
            Check(backend.Writes == 2, "dependency failure zero new effects");
        }
        finally { await app.StopAsync(); }
        Console.WriteLine("C# order review: native, policy, Web authentication, route, dependency checks passed");
    }
}
