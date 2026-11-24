#nullable enable
using System;
using System.Linq;
using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tutorial.Finops
{
    public sealed class FixtureModel : IModel
    {
        private readonly string _account;

        public FixtureModel(string account) { _account = account; }

        public Response Generate(Request request)
        {
            var results = request.Messages.Where(message => message.Role == Roles.Tool).ToArray();
            if (results.Length == 0)
            {
                return Call("costs-1", "read_costs", new JsonObject { ["account"] = _account });
            }
            if (results.Length == 1)
            {
                var costs = JsonNode.Parse(results[0].Content!)!;
                var action = costs["candidate"] is JsonObject ? "review_termination" : "review_hold";
                return Call("review-1", "draft_review",
                    new JsonObject { ["account"] = _account, ["action"] = action });
            }
            var costReport = JsonNode.Parse(results[0].Content!);
            var review = JsonNode.Parse(results[^1].Content!);
            return new Response
            {
                Message = Message.Assistant(new JsonObject
                {
                    ["stage"] = "finops_review_drafted",
                    ["costs"] = costReport,
                    ["review"] = review,
                    ["terminations_executed"] = 0,
                }.ToJsonString()),
            };
        }

        private static Response Call(string id, string name, JsonObject arguments)
            => new Response
            {
                Message = Message.Assistant("", new[]
                {
                    new ToolCall { Id = id, Name = name, Arguments = arguments },
                }),
            };
    }

    public sealed class CostPolicy : IPolicyHook
    {
        public Decision Authorize(Praxo.Core.Action action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("fixture model");
            if (action.Kind != "tool.invoke") return Decision.Deny("unsupported action");
            if (action.Arguments?["account"]?.GetValue<string>() != "account-100")
                return Decision.Deny("account outside scope");
            if (action.ToolName == "read_costs") return Decision.Allow("fixed cost fixture");
            if (action.ToolName == "draft_review")
            {
                string? choice = action.Arguments?["action"]?.GetValue<string>();
                return choice == "review_termination" || choice == "review_hold"
                    ? Decision.Allow("review-only action") : Decision.Deny("unsupported review action");
            }
            return Decision.Deny("unsupported tool");
        }
    }

    public sealed class CostTool : ITool, IToolSpecProvider
    {
        private readonly bool _simulateFailure;
        public string Name => "read_costs";
        public string Description => "Read fixed resource costs and compute an idle-resource candidate; no cloud calls.";
        public int Calls { get; private set; }

        public CostTool(bool simulateFailure) { _simulateFailure = simulateFailure; }

        public JsonNode? Invoke(JsonObject arguments)
        {
            if (arguments["account"]?.GetValue<string>() != "account-100")
                throw new ArgumentException("account outside fixture");
            Calls++;
            if (_simulateFailure) throw new InvalidOperationException("BILLING_UNAVAILABLE");
            var resources = new JsonArray
            {
                new JsonObject { ["id"] = "vm-1", ["monthly_cost"] = 420, ["utilization"] = 0.03 },
                new JsonObject { ["id"] = "vm-2", ["monthly_cost"] = 300, ["utilization"] = 0.12 },
                new JsonObject { ["id"] = "disk-1", ["monthly_cost"] = 80, ["utilization"] = 0.02 },
            };
            JsonObject? candidate = null;
            foreach (var node in resources)
            {
                var item = node!.AsObject();
                if (item["utilization"]!.GetValue<double>() >= 0.05) continue;
                if (candidate == null || item["monthly_cost"]!.GetValue<int>() > candidate["monthly_cost"]!.GetValue<int>())
                    candidate = item.DeepClone().AsObject();
            }
            return new JsonObject
            {
                ["account"] = "account-100",
                ["resources"] = resources,
                ["candidate"] = candidate,
                ["idle_threshold"] = 0.05,
                ["source"] = "cost_fixture",
            };
        }

        public ToolSpec Spec() => new ToolSpec
        {
            Name = Name, Description = Description, Risk = "read",
            Parameters = JsonNode.Parse("""
                {"type":"object","required":["account"],"properties":{"account":{"type":"string"}}}
                """)!.AsObject(),
        };
    }

    public sealed class ReviewTool : ITool, IToolSpecProvider
    {
        public string Name => "draft_review";
        public string Description => "Draft a review-only cost action; never terminates resources.";
        public int Calls { get; private set; }

        public JsonNode? Invoke(JsonObject arguments)
        {
            if (arguments["account"]?.GetValue<string>() != "account-100")
                throw new ArgumentException("account outside fixture");
            Calls++;
            return new JsonObject
            {
                ["review_id"] = "finops-100",
                ["account"] = "account-100",
                ["action"] = arguments["action"]?.GetValue<string>(),
                ["status"] = "draft_only",
                ["review_required"] = true,
                ["terminations_executed"] = 0,
            };
        }

        public ToolSpec Spec() => new ToolSpec
        {
            Name = Name, Description = Description, Risk = "write",
            Parameters = JsonNode.Parse("""
                {"type":"object","required":["account","action"],"properties":{"account":{"type":"string"},"action":{"type":"string"}}}
                """)!.AsObject(),
        };
    }
}
