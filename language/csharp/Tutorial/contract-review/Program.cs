using System.Text.Json.Nodes;
using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.ContractReview;

public static class Program
{
    public const string ScopeId = "contract-100";
    public const string ScopeKey = "contract_id";
    public const string ToolName = "compare_clauses";
    public const string ActionName = "draft_redline";
    public const string ErrorCode = "CONTRACT_DATA_UNAVAILABLE";

    public sealed record Outcome(string Output, int Reads);

    private sealed class FixtureModel(string scope) : IModel
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
                            Id = "tool-1", Name = ToolName,
                            Arguments = new JsonObject
                            {
                                [ScopeKey] = scope,
                                ["action"] = ActionName,
                            },
                        },
                    }),
                };
            }
            var result = JsonNode.Parse(request.Messages.Last(message => message.Role == Roles.Tool).Content!)!;
            var report = new JsonObject
            {
                ["stage"] = "contract_drafted",
                ["result"] = result.DeepClone(),
                ["writes"] = 0,
            };
            return new Response { Message = Message.Assistant(report.ToJsonString()) };
        }
    }

    public sealed class FixtureTool(int[] reads, bool simulateFailure) : ITool, IToolSpecProvider
    {
        public string Name => ToolName;
        public string Description => "Read fixed contract review fixtures and draft a review-only result.";

        public ToolSpec Spec() => new()
        {
            Name = Name, Description = Description, Risk = "write",
            Parameters = JsonNode.Parse(
                """{"type":"object","required":["contract_id","action"],"properties":{"contract_id":{"type":"string"},"action":{"type":"string"}}}""")!.AsObject(),
        };

        public JsonNode? Invoke(JsonObject arguments)
        {
            reads[0]++;
            if (arguments[ScopeKey]?.GetValue<string>() != ScopeId)
                throw new InvalidOperationException("scope outside fixture");
            if (simulateFailure) throw new InvalidOperationException(ErrorCode);
            return new JsonObject
            {
                ["id"] = ScopeId,
                ["count"] = 2,
                ["secondary"] = 1,
                ["status"] = "draft_only",
                ["review_required"] = true,
                ["writes"] = 0,
                ["source"] = "fixture",
            };
        }
    }

    private sealed class FixturePolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("deterministic tutorial review");
            if (action.Kind != "tool.invoke") return Decision.Deny("unsupported action");
            string? scope = action.Arguments?[ScopeKey]?.GetValue<string>();
            if (scope != ScopeId) return Decision.Deny($"only {ScopeId} is in scope");
            if (action.ToolName == ToolName &&
                action.Arguments?["action"]?.GetValue<string>() == ActionName)
                return Decision.Allow($"{ScopeId} review-only draft");
            return Decision.Deny("only a review-only draft is allowed");
        }
    }

    public static Outcome Run(string scope, bool simulateFailure)
    {
        int[] reads = [0];
        var tools = new ToolRegistry();
        tools.Register(new FixtureTool(reads, simulateFailure));
        var options = new AgentOptions(new FixtureModel(scope))
        {
            Tools = tools,
            AllowedTools = new List<string> { ToolName },
            Policy = new FixturePolicy(),
            RequirePolicy = true,
            RequireToolScope = true,
            MaxSteps = 3,
        };
        var result = new Agent(options).Run(new Session("contract-review"), "Read fixed contract review fixtures and draft a review-only result.");
        return new Outcome(result.Output, reads[0]);
    }

    private static void Check(bool condition, string name)
    {
        if (!condition) throw new InvalidOperationException($"Failed: {name}");
    }

    public static int Main(string[] args)
    {
        if (args.SequenceEqual(new[] { "--test" }))
        {
            var success = Run(ScopeId, false);
            var report = JsonNode.Parse(success.Output)!;
            var result = report["result"]!;
            Check(result["status"]!.GetValue<string>() == "draft_only", "status");
            Check(result["writes"]!.GetValue<int>() == 0, "writes");
            Check(report["writes"]!.GetValue<int>() == 0, "report writes");
            Check(success.Reads == 1, "reads");
            Console.WriteLine($"success: {ScopeId} status=draft_only writes=0 reads=1");

            try
            {
                Run("contract-200", false);
                throw new InvalidOperationException("out-of-scope fixture was accepted");
            }
            catch (PraxoException error) when (error.Code == "AGENT_POLICY_DENIED") { }
            Console.WriteLine("deny: AGENT_POLICY_DENIED reads=0");

            try
            {
                Run(ScopeId, true);
                throw new InvalidOperationException("simulated failure did not fail");
            }
            catch (Exception error) when (error.Message.Contains(ErrorCode)) { }
            Console.WriteLine($"failure: {ErrorCode} reads=1");
            return 0;
        }

        string scope = ScopeId;
        for (int index = 0; index < args.Length; index++)
        {
            if (args[index] == "--contract" && index + 1 < args.Length) scope = args[++index];
        }
        try
        {
            Console.WriteLine(Run(scope, args.Contains("--simulate-failure")).Output);
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error.Message);
            return 1;
        }
    }
}
