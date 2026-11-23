using System.Net;
using System.Net.Http.Headers;
using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.SalesCrm;

internal static class SelfTest
{
    private static void Check(bool condition, string name)
    {
        if (!condition) throw new InvalidOperationException($"Failed: {name}");
    }

    public static async Task Run()
    {
        var success = Program.Review("customer-100", false);
        var report = JsonNode.Parse(success.Output)!;
        Check(report["draft"]!["status"]!.GetValue<string>() == "draft_only", "native draft status");
        Check(report["draft"]!["action"]!.GetValue<string>() == "review_required", "native review action");
        Check(report["crm_writes"] is JsonArray { Count: 0 }, "native zero CRM writes");
        Check(success.Reads == 2, "native read count");

        try
        {
            Program.Review("customer-200", false);
            throw new InvalidOperationException("out-of-scope customer was accepted");
        }
        catch (PraxoException error) when (error.Code == "AGENT_POLICY_DENIED") { }

        try
        {
            Program.Review("customer-100", true);
            throw new InvalidOperationException("simulated CRM failure did not fail");
        }
        catch (Exception error) when (error.Message.Contains("simulated CRM")) { }

        await using var app = Program.CreateApp("http://127.0.0.1:0");
        await using var failureApp = Program.CreateApp("http://127.0.0.1:0", simulateFailure: true);
        await app.StartAsync();
        await failureApp.StartAsync();
        try
        {
            using var client = new HttpClient(new HttpClientHandler { UseProxy = false })
            {
                BaseAddress = new Uri(app.Urls.First()), Timeout = TimeSpan.FromSeconds(10),
            };
            using var denied = await client.PostAsync("/followup/customer-100", null);
            Check(denied.StatusCode == HttpStatusCode.Unauthorized, "Web authentication");
            client.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", "demo-sales-token");
            using var allowed = await client.PostAsync("/followup/customer-100", null);
            Check(allowed.StatusCode == HttpStatusCode.OK, "Web allow");
            var allowedReport = JsonNode.Parse(await allowed.Content.ReadAsStringAsync())!;
            Check(allowedReport["draft"]!["status"]!.GetValue<string>() == "draft_only", "Web draft");
            Check(allowedReport["crm_writes"] is JsonArray { Count: 0 }, "Web zero CRM writes");

            using var failingClient = new HttpClient(new HttpClientHandler { UseProxy = false })
            {
                BaseAddress = new Uri(failureApp.Urls.First()), Timeout = TimeSpan.FromSeconds(10),
            };
            failingClient.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", "demo-sales-token");
            using var failed = await failingClient.PostAsync("/followup/customer-100", null);
            Check(failed.StatusCode == HttpStatusCode.ServiceUnavailable, "Web dependency failure");
        }
        finally
        {
            await failureApp.StopAsync();
            await app.StopAsync();
        }

        Console.WriteLine("C# sales-crm tutorial: all checks passed");
    }
}
