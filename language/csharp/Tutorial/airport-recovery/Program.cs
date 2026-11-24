using System.Text.Json.Nodes;
using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.AirportRecovery;

public static class Program
{
    private sealed class FixtureModel(string flightId) : IModel
    {
        public Response Generate(Request request)
        {
            var toolMessages = request.Messages.Where(message => message.Role == Roles.Tool).ToList();
            if (toolMessages.Count == 0)
            {
                return new Response
                {
                    Message = Message.Assistant("", new[]
                    {
                        new ToolCall
                        {
                            Id = "constraints-1", Name = "read_constraints",
                            Arguments = new JsonObject { ["flight_id"] = flightId },
                        },
                    }),
                };
            }
            if (toolMessages.Count == 1)
            {
                return new Response
                {
                    Message = Message.Assistant("", new[]
                    {
                        new ToolCall
                        {
                            Id = "recovery-1", Name = "draft_recovery",
                            Arguments = new JsonObject
                            {
                                ["flight_id"] = flightId,
                                ["action"] = "draft_recovery",
                            },
                        },
                    }),
                };
            }
            var constraints = JsonNode.Parse(toolMessages[0].Content ?? "{}");
            var recovery = JsonNode.Parse(toolMessages[^1].Content ?? "{}");
            return new Response
            {
                Message = Message.Assistant(new JsonObject
                {
                    ["stage"] = "recovery_drafted",
                    ["constraints"] = constraints,
                    ["recovery"] = recovery,
                    ["schedule_commands"] = 0,
                    ["latency_claims"] = 0,
                }.ToJsonString()),
            };
        }
    }

    private sealed class RecoveryPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("deterministic airport recovery");
            if (action.Kind != "tool.invoke") return Decision.Deny("unsupported action");
            var inScope = action.Arguments?["flight_id"]?.GetValue<string>() == "flight-100";
            return action.ToolName switch
            {
                "read_constraints" => inScope
                    ? Decision.Allow("only flight-100 is in scope")
                    : Decision.Deny("flight outside scope"),
                "draft_recovery" => inScope
                    && action.Arguments?["action"]?.GetValue<string>() == "draft_recovery"
                    ? Decision.Allow("review-only recovery draft")
                    : Decision.Deny("only a flight-100 draft_recovery is allowed"),
                _ => Decision.Deny("unsupported tool"),
            };
        }
    }

    public static (JsonObject? Report, int Reads, int Drafts, Exception? Error) Run(
        string flightId, bool simulateFailure = false)
    {
        var reads = 0;
        var drafts = 0;
        var tools = new ToolRegistry();
        tools.Register(new FuncTool("read_constraints",
            "Read fixed gate/crew/connection constraints; no live schedule.",
            arguments =>
            {
                if (arguments["flight_id"]?.GetValue<string>() != "flight-100")
                    throw new InvalidOperationException("flight not found");
                reads += 1;
                if (simulateFailure) throw new InvalidOperationException("AIRPORT_INDEX_UNAVAILABLE");
                return new JsonObject
                {
                    ["flight_id"] = "flight-100",
                    ["gates"] = 3,
                    ["crew_ok"] = false,
                    ["connections"] = 2,
                    ["delay_min"] = 40,
                    ["source"] = "airport_fixture",
                };
            }));
        tools.Register(new FuncTool("draft_recovery",
            "Draft review-only recovery options; never commands a schedule.",
            arguments =>
            {
                drafts += 1;
                return new JsonObject
                {
                    ["recovery_id"] = "airport-100",
                    ["flight_id"] = arguments["flight_id"]?.GetValue<string>(),
                    ["action"] = arguments["action"]?.GetValue<string>(),
                    ["options"] = new JsonArray("swap-gate", "swap-crew"),
                    ["status"] = "draft_only",
                    ["review_required"] = true,
                    ["schedule_commands"] = 0,
                    ["latency_claims"] = 0,
                };
            }));
        var options = new AgentOptions(new FixtureModel(flightId))
        {
            Tools = tools,
            MaxSteps = 4,
            AllowedTools = new List<string> { "read_constraints", "draft_recovery" },
            Policy = new RecoveryPolicy(),
            RequirePolicy = true,
            RequireToolScope = true,
        };
        try
        {
            var result = new Agent(options).Run(
                new Session("airport-recovery"),
                "Read the fixed constraints and draft review-only recovery options.");
            var decoded = JsonNode.Parse(result.Output) as JsonObject;
            return (decoded, reads, drafts, null);
        }
        catch (Exception error)
        {
            return (null, reads, drafts, error);
        }
    }

    private static void Test()
    {
        var (report, reads, drafts, error) = Run("flight-100");
        if (error is not null || reads != 1 || drafts != 1 || report is null)
            throw new InvalidOperationException($"success failed: reads={reads} drafts={drafts} {error?.Message}");
        if (report["stage"]?.GetValue<string>() != "recovery_drafted"
            || report["constraints"]?["delay_min"]?.GetValue<int>() != 40
            || report["constraints"]?["crew_ok"]?.GetValue<bool>() != false
            || report["recovery"]?["status"]?.GetValue<string>() != "draft_only"
            || report["schedule_commands"]?.GetValue<int>() != 0
            || report["latency_claims"]?.GetValue<int>() != 0)
            throw new InvalidOperationException($"unexpected report: {report}");
        Console.WriteLine("success: flight-100 delay_min=40 crew_ok=false status=draft_only commands=0 reads=1");

        var denied = Run("flight-200");
        if (denied.Error is not PraxoException { Code: "AGENT_POLICY_DENIED" }
            || denied.Reads != 0 || denied.Drafts != 0)
            throw new InvalidOperationException($"deny failed: reads={denied.Reads} drafts={denied.Drafts}");
        Console.WriteLine("deny: AGENT_POLICY_DENIED reads=0");

        var failed = Run("flight-100", simulateFailure: true);
        if (failed.Error is null || failed.Reads != 1 || failed.Drafts != 0)
            throw new InvalidOperationException($"failure failed: reads={failed.Reads} drafts={failed.Drafts}");
        Console.WriteLine("failure: AIRPORT_INDEX_UNAVAILABLE reads=1");
    }

    public static int Main(string[] args)
    {
        if (args.SequenceEqual(new[] { "--test" }))
        {
            Test();
            return 0;
        }
        var flight = "flight-100";
        var index = Array.IndexOf(args, "--flight");
        if (index >= 0 && index + 1 < args.Length) flight = args[index + 1];
        var (report, reads, drafts, error) = Run(flight, args.Contains("--simulate-failure"));
        if (error is not null)
        {
            Console.Error.WriteLine($"airport recovery failed: reads={reads} drafts={drafts}; {error.Message}");
            return 1;
        }
        Console.WriteLine(report);
        return 0;
    }
}
