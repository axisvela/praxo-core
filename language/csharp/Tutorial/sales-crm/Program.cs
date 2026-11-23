using System.Text.Json.Nodes;
using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.SalesCrm;

public static class Program
{
    public sealed record ReviewResult(string Output, int Reads);

    private sealed class FixtureModel(string customerId) : IModel
    {
        public Response Generate(Request request)
        {
            int tools = request.Messages.Count(message => message.Role == Roles.Tool);
            if (tools == 0)
            {
                return new Response
                {
                    Message = Message.Assistant("", new[]
                    {
                        new ToolCall
                        {
                            Id = "customer-1", Name = "read_customer",
                            Arguments = new JsonObject { ["customer_id"] = customerId },
                        },
                    }),
                };
            }
            if (tools == 1)
            {
                return new Response
                {
                    Message = Message.Assistant("", new[]
                    {
                        new ToolCall
                        {
                            Id = "draft-1", Name = "draft_followup",
                            Arguments = new JsonObject
                            {
                                ["customer_id"] = customerId,
                                ["note"] = "Send the proposal follow-up.",
                            },
                        },
                    }),
                };
            }
            var draft = JsonNode.Parse(request.Messages.Last(message => message.Role == Roles.Tool).Content!)!;
            var report = new JsonObject
            {
                ["recommendation"] = "Review the follow-up draft; no CRM record was written.",
                ["citations"] = new JsonArray { customerId },
                ["draft"] = draft.DeepClone(),
                ["crm_writes"] = new JsonArray(),
            };
            return new Response { Message = Message.Assistant(report.ToJsonString()) };
        }
    }

    public sealed class ReadCustomerTool(int[] reads, bool simulateFailure) : ITool, IToolSpecProvider
    {
        public string Name => "read_customer";
        public string Description => "Read the fixed CRM customer fixture; no writes.";

        public ToolSpec Spec() => new()
        {
            Name = Name, Description = Description, Risk = "read",
            Parameters = JsonNode.Parse("""
                {"type":"object","required":["customer_id"],"properties":{"customer_id":{"type":"string"}}}
                """)!.AsObject(),
        };

        public JsonNode? Invoke(JsonObject arguments)
        {
            reads[0]++;
            if (simulateFailure) throw new InvalidOperationException("simulated CRM dependency unavailable");
            if (arguments["customer_id"]?.GetValue<string>() != "customer-100")
                throw new InvalidOperationException("customer not found");
            return new JsonObject
            {
                ["id"] = "customer-100",
                ["name"] = "Acme",
                ["segment"] = "enterprise",
                ["stage"] = "proposal",
                ["owner"] = "rep-7",
            };
        }
    }

    public sealed class DraftFollowupTool(int[] reads) : ITool, IToolSpecProvider
    {
        public string Name => "draft_followup";
        public string Description => "Draft a follow-up for human review; never writes the CRM.";

        public ToolSpec Spec() => new()
        {
            Name = Name, Description = Description, Risk = "write",
            Parameters = JsonNode.Parse("""
                {"type":"object","required":["customer_id","note"],"properties":{"customer_id":{"type":"string"},"note":{"type":"string"}}}
                """)!.AsObject(),
        };

        public JsonNode? Invoke(JsonObject arguments)
        {
            reads[0]++;
            if (arguments["customer_id"]?.GetValue<string>() != "customer-100")
                throw new InvalidOperationException("customer not found");
            string note = arguments["note"]?.GetValue<string>() ?? "";
            if (note.Length == 0 || note.Length > 500)
                throw new InvalidOperationException("invalid follow-up note");
            return new JsonObject
            {
                ["draft_id"] = "followup-1",
                ["customer_id"] = "customer-100",
                ["status"] = "draft_only",
                ["action"] = "review_required",
                ["note"] = note,
            };
        }
    }

    private sealed class SalesPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("fixture model");
            if (action.Kind != "tool.invoke") return Decision.Deny("unsupported action");
            string? customer = action.Arguments?["customer_id"]?.GetValue<string>();
            if (customer != "customer-100") return Decision.Deny("customer outside sales scope");
            if (action.ToolName == "read_customer") return Decision.Allow("read-only customer fixture");
            if (action.ToolName == "draft_followup")
            {
                string? note = action.Arguments?["note"]?.GetValue<string>();
                return note is { Length: > 0 and <= 500 }
                    ? Decision.Allow("bounded follow-up draft")
                    : Decision.Deny("invalid follow-up note");
            }
            return Decision.Deny("unsupported tool");
        }
    }

    public static ReviewResult Review(string customerId, bool simulateFailure)
    {
        int[] reads = [0];
        var tools = new ToolRegistry();
        tools.Register(new ReadCustomerTool(reads, simulateFailure));
        tools.Register(new DraftFollowupTool(reads));
        var options = new AgentOptions(new FixtureModel(customerId))
        {
            Tools = tools,
            AllowedTools = new List<string> { "read_customer", "draft_followup" },
            Policy = new SalesPolicy(),
            RequirePolicy = true,
            RequireToolScope = true,
            MaxSteps = 4,
        };
        var result = new Agent(options).Run(new Session("sales-crm"),
            "Read the fixed customer and draft a follow-up only.");
        return new ReviewResult(result.Output, reads[0]);
    }

    public static WebApplication CreateApp(string url, bool simulateFailure = false)
    {
        var builder = WebApplication.CreateSlimBuilder();
        builder.Logging.ClearProviders();
        builder.WebHost.UseUrls(url);
        var app = builder.Build();
        app.MapGet("/healthz", () => Results.Text("{\"status\":\"ok\"}", "application/json"));
        app.MapPost("/followup/customer-100", (HttpContext context) =>
        {
            if (context.Request.Headers.Authorization.ToString() != "Bearer demo-sales-token")
                return Results.Text("{\"error\":\"unauthenticated\"}", "application/json", statusCode: 401);
            try
            {
                return Results.Text(Review("customer-100", simulateFailure).Output,
                    "application/json");
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
        try
        {
            if (args.SequenceEqual(new[] { "--serve" }))
            {
                await using var app = CreateApp(
                    Environment.GetEnvironmentVariable("DEMO_WEB_URL") ?? "http://127.0.0.1:8091");
                await app.RunAsync();
            }
            else
            {
                Console.WriteLine(Review("customer-100", false).Output);
            }
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error.Message);
            return 1;
        }
    }
}
