using System.Text.Json.Nodes;
using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.MedicalCoding;

public static class Program
{
    private sealed class FixtureModel(string recordId) : IModel
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
                            Id = "record-1", Name = "read_record",
                            Arguments = new JsonObject { ["record_id"] = recordId },
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
                            Id = "codes-1", Name = "draft_codes",
                            Arguments = new JsonObject
                            {
                                ["record_id"] = recordId,
                                ["action"] = "draft_codes",
                            },
                        },
                    }),
                };
            }
            var record = JsonNode.Parse(toolMessages[0].Content ?? "{}");
            var codes = JsonNode.Parse(toolMessages[^1].Content ?? "{}");
            return new Response
            {
                Message = Message.Assistant(new JsonObject
                {
                    ["stage"] = "codes_drafted",
                    ["record"] = record,
                    ["codes"] = codes,
                    ["billing_submissions"] = 0,
                    ["reimbursement_optimizations"] = 0,
                }.ToJsonString()),
            };
        }
    }

    private sealed class CodingPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("deterministic coding review");
            if (action.Kind != "tool.invoke") return Decision.Deny("unsupported action");
            var inScope = action.Arguments?["record_id"]?.GetValue<string>() == "record-100";
            return action.ToolName switch
            {
                "read_record" => inScope
                    ? Decision.Allow("only record-100 is in scope")
                    : Decision.Deny("record outside scope"),
                "draft_codes" => inScope
                    && action.Arguments?["action"]?.GetValue<string>() == "draft_codes"
                    ? Decision.Allow("review-only coding draft")
                    : Decision.Deny("only a record-100 draft_codes is allowed"),
                _ => Decision.Deny("unsupported tool"),
            };
        }
    }

    public static (JsonObject? Report, int Reads, int Drafts, Exception? Error) Run(
        string recordId, bool simulateFailure = false)
    {
        var reads = 0;
        var drafts = 0;
        var tools = new ToolRegistry();
        tools.Register(new FuncTool("read_record",
            "Check fixed record completeness; no billing submission.",
            arguments =>
            {
                if (arguments["record_id"]?.GetValue<string>() != "record-100")
                    throw new InvalidOperationException("record not found");
                reads += 1;
                if (simulateFailure) throw new InvalidOperationException("RECORD_UNAVAILABLE");
                return new JsonObject
                {
                    ["record_id"] = "record-100",
                    ["fields"] = 6,
                    ["missing"] = new JsonArray("attending"),
                    ["completeness"] = 0.83,
                    ["source"] = "record_fixture",
                };
            }));
        tools.Register(new FuncTool("draft_codes",
            "Draft review-only codes; no reimbursement optimization.",
            arguments =>
            {
                drafts += 1;
                return new JsonObject
                {
                    ["codes_id"] = "coding-100",
                    ["record_id"] = arguments["record_id"]?.GetValue<string>(),
                    ["action"] = arguments["action"]?.GetValue<string>(),
                    ["codes"] = new JsonArray("I10", "E11.9"),
                    ["status"] = "draft_only",
                    ["review_required"] = true,
                    ["billing_submissions"] = 0,
                    ["reimbursement_optimizations"] = 0,
                };
            }));
        var options = new AgentOptions(new FixtureModel(recordId))
        {
            Tools = tools,
            MaxSteps = 4,
            AllowedTools = new List<string> { "read_record", "draft_codes" },
            Policy = new CodingPolicy(),
            RequirePolicy = true,
            RequireToolScope = true,
        };
        try
        {
            var result = new Agent(options).Run(
                new Session("medical-coding"),
                "Check the fixed record and draft review-only codes.");
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
        var (report, reads, drafts, error) = Run("record-100");
        if (error is not null || reads != 1 || drafts != 1 || report is null)
            throw new InvalidOperationException($"success failed: reads={reads} drafts={drafts} {error?.Message}");
        if (report["stage"]?.GetValue<string>() != "codes_drafted"
            || report["record"]?["completeness"]?.GetValue<double>() != 0.83
            || report["codes"]?["status"]?.GetValue<string>() != "draft_only"
            || report["billing_submissions"]?.GetValue<int>() != 0
            || report["reimbursement_optimizations"]?.GetValue<int>() != 0)
            throw new InvalidOperationException($"unexpected report: {report}");
        Console.WriteLine("success: record-100 fields=6 missing=1 status=draft_only submissions=0 reads=1");

        var denied = Run("record-200");
        if (denied.Error is not PraxoException { Code: "AGENT_POLICY_DENIED" }
            || denied.Reads != 0 || denied.Drafts != 0)
            throw new InvalidOperationException($"deny failed: reads={denied.Reads} drafts={denied.Drafts}");
        Console.WriteLine("deny: AGENT_POLICY_DENIED reads=0");

        var failed = Run("record-100", simulateFailure: true);
        if (failed.Error is null || failed.Reads != 1 || failed.Drafts != 0)
            throw new InvalidOperationException($"failure failed: reads={failed.Reads} drafts={failed.Drafts}");
        Console.WriteLine("failure: RECORD_UNAVAILABLE reads=1");
    }

    public static int Main(string[] args)
    {
        if (args.SequenceEqual(new[] { "--test" }))
        {
            Test();
            return 0;
        }
        var record = "record-100";
        var index = Array.IndexOf(args, "--record");
        if (index >= 0 && index + 1 < args.Length) record = args[index + 1];
        var (report, reads, drafts, error) = Run(record, args.Contains("--simulate-failure"));
        if (error is not null)
        {
            Console.Error.WriteLine($"medical coding failed: reads={reads} drafts={drafts}; {error.Message}");
            return 1;
        }
        Console.WriteLine(report);
        return 0;
    }
}
