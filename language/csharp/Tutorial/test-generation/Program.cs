using System.Text.Json.Nodes;
using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.TestGeneration;

public static class Program
{
    private sealed class FixtureModel(string fixtureId) : IModel
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
                            Id = "fixture-1", Name = "read_fixture",
                            Arguments = new JsonObject { ["fixture_id"] = fixtureId },
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
                            Id = "tests-1", Name = "draft_tests",
                            Arguments = new JsonObject
                            {
                                ["fixture_id"] = fixtureId,
                                ["action"] = "generate_tests",
                            },
                        },
                    }),
                };
            }
            var fixture = JsonNode.Parse(toolMessages[0].Content ?? "{}");
            var suite = JsonNode.Parse(toolMessages[^1].Content ?? "{}");
            return new Response
            {
                Message = Message.Assistant(new JsonObject
                {
                    ["stage"] = "tests_generated",
                    ["fixture"] = fixture,
                    ["suite"] = suite,
                    ["executions"] = 0,
                    ["load_targets"] = 0,
                }.ToJsonString()),
            };
        }
    }

    private sealed class TestPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("deterministic test generation");
            if (action.Kind != "tool.invoke") return Decision.Deny("unsupported action");
            var inScope = action.Arguments?["fixture_id"]?.GetValue<string>() == "fixture-100";
            return action.ToolName switch
            {
                "read_fixture" => inScope
                    ? Decision.Allow("only fixture-100 is in scope")
                    : Decision.Deny("fixture outside scope"),
                "draft_tests" => inScope
                    && action.Arguments?["action"]?.GetValue<string>() == "generate_tests"
                    ? Decision.Allow("review-only test suite draft")
                    : Decision.Deny("only a fixture-100 generate_tests is allowed"),
                _ => Decision.Deny("unsupported tool"),
            };
        }
    }

    public static (JsonObject? Report, int Reads, int Drafts, Exception? Error) Run(
        string fixtureId, bool simulateFailure = false)
    {
        var reads = 0;
        var drafts = 0;
        var tools = new ToolRegistry();
        tools.Register(new FuncTool("read_fixture",
            "Read a fixed local fixture; no execution.",
            arguments =>
            {
                if (arguments["fixture_id"]?.GetValue<string>() != "fixture-100")
                    throw new InvalidOperationException("fixture not found");
                reads += 1;
                if (simulateFailure) throw new InvalidOperationException("FIXTURE_INDEX_UNAVAILABLE");
                return new JsonObject
                {
                    ["fixture_id"] = "fixture-100",
                    ["functions"] = 2,
                    ["last_failure"] = "parse",
                    ["language"] = "csharp",
                    ["source"] = "fixture_fixture",
                };
            }));
        tools.Register(new FuncTool("draft_tests",
            "Draft review-only bounded tests; never executes or loads.",
            arguments =>
            {
                drafts += 1;
                return new JsonObject
                {
                    ["suite_id"] = "tests-100",
                    ["fixture_id"] = arguments["fixture_id"]?.GetValue<string>(),
                    ["action"] = arguments["action"]?.GetValue<string>(),
                    ["generated_tests"] = 3,
                    ["coverage_targets"] = new JsonArray("parse", "format"),
                    ["status"] = "draft_only",
                    ["review_required"] = true,
                    ["executions"] = 0,
                    ["load_targets"] = 0,
                };
            }));
        var options = new AgentOptions(new FixtureModel(fixtureId))
        {
            Tools = tools,
            MaxSteps = 4,
            AllowedTools = new List<string> { "read_fixture", "draft_tests" },
            Policy = new TestPolicy(),
            RequirePolicy = true,
            RequireToolScope = true,
        };
        try
        {
            var result = new Agent(options).Run(
                new Session("test-generation"),
                "Generate bounded tests for the fixed fixture.");
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
        var (report, reads, drafts, error) = Run("fixture-100");
        if (error is not null || reads != 1 || drafts != 1 || report is null)
            throw new InvalidOperationException($"success failed: reads={reads} drafts={drafts} {error?.Message}");
        if (report["stage"]?.GetValue<string>() != "tests_generated"
            || report["fixture"]?["functions"]?.GetValue<int>() != 2
            || report["suite"]?["generated_tests"]?.GetValue<int>() != 3
            || report["suite"]?["status"]?.GetValue<string>() != "draft_only"
            || report["executions"]?.GetValue<int>() != 0
            || report["load_targets"]?.GetValue<int>() != 0)
            throw new InvalidOperationException($"unexpected report: {report}");
        Console.WriteLine("success: fixture-100 functions=2 tests=3 status=draft_only executions=0 reads=1");

        var denied = Run("fixture-200");
        if (denied.Error is not PraxoException { Code: "AGENT_POLICY_DENIED" }
            || denied.Reads != 0 || denied.Drafts != 0)
            throw new InvalidOperationException($"deny failed: reads={denied.Reads} drafts={denied.Drafts}");
        Console.WriteLine("deny: AGENT_POLICY_DENIED reads=0");

        var failed = Run("fixture-100", simulateFailure: true);
        if (failed.Error is null || failed.Reads != 1 || failed.Drafts != 0)
            throw new InvalidOperationException($"failure failed: reads={failed.Reads} drafts={failed.Drafts}");
        Console.WriteLine("failure: FIXTURE_INDEX_UNAVAILABLE reads=1");
    }

    public static int Main(string[] args)
    {
        if (args.SequenceEqual(new[] { "--test" }))
        {
            Test();
            return 0;
        }
        var fixture = "fixture-100";
        var index = Array.IndexOf(args, "--fixture");
        if (index >= 0 && index + 1 < args.Length) fixture = args[index + 1];
        var (report, reads, drafts, error) = Run(fixture, args.Contains("--simulate-failure"));
        if (error is not null)
        {
            Console.Error.WriteLine($"test generation failed: reads={reads} drafts={drafts}; {error.Message}");
            return 1;
        }
        Console.WriteLine(report);
        return 0;
    }
}
