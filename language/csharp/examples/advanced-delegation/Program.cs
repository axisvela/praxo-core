using System.Text.Json.Nodes;

using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.AdvancedDelegation;

public static class Program
{
    private sealed class FixtureModel : IModel
    {
        private readonly string _tool;
        private readonly JsonObject _arguments;
        private readonly string _completion;
        private int _calls;

        public FixtureModel(string tool, JsonObject arguments, string completion)
        {
            _tool = tool;
            _arguments = arguments;
            _completion = completion;
        }

        public Response Generate(Request request)
        {
            _calls += 1;
            if (request.Messages[^1].Role == Roles.Tool)
            {
                return new Response { Message = Message.Assistant(_completion) };
            }
            return new Response
            {
                Message = Message.Assistant("", new[]
                {
                    new ToolCall
                    {
                        Id = $"call-{_calls}",
                        Name = _tool,
                        Arguments = _arguments.DeepClone().AsObject(),
                    },
                }),
            };
        }
    }

    private sealed class RecordTool : ITool, IToolSpecProvider
    {
        public int Calls { get; private set; }

        public string Name => "record";

        public string Description => "Record a child result in an in-memory counter.";

        public JsonNode? Invoke(JsonObject arguments)
        {
            Calls += 1;
            return JsonValue.Create($"recorded:{arguments["target"]?.GetValue<string>()}");
        }

        public ToolSpec Spec() => new()
        {
            Name = Name,
            Description = Description,
            Parameters = JsonNode.Parse("""
                {
                  "type": "object",
                  "required": ["target"],
                  "properties": {"target": {"type": "string"}}
                }
                """)!.AsObject(),
            Risk = "write",
        };
    }

    private sealed class ParentOnlyTool : ITool
    {
        public string Name => "parent_only";

        public string Description => "A tool that must remain outside the child scope.";

        public JsonNode? Invoke(JsonObject arguments) => JsonValue.Create("parent-effect");
    }

    private sealed class DelegateTool : ITool, IToolSpecProvider
    {
        private readonly RecordTool _record;

        public DelegateTool(RecordTool record)
        {
            _record = record;
        }

        public string Name => "delegate";

        public string Description => "Run the child agent with a restricted tool scope.";

        public JsonNode? Invoke(JsonObject arguments)
        {
            var child = BuildChild(_record);
            var result = child.Run(
                new Session("advanced-delegation-child"),
                arguments["task"]?.GetValue<string>() ?? "");
            return new JsonObject
            {
                ["output"] = result.Output,
                ["effects"] = _record.Calls,
            };
        }

        public ToolSpec Spec() => new()
        {
            Name = Name,
            Description = Description,
            Parameters = JsonNode.Parse("""
                {
                  "type": "object",
                  "required": ["task"],
                  "properties": {"task": {"type": "string"}}
                }
                """)!.AsObject(),
            Risk = "write",
        };
    }

    private static Agent BuildChild(RecordTool record)
    {
        var tools = new ToolRegistry();
        tools.Register(record);
        var options = new AgentOptions(
            new FixtureModel("record", new JsonObject { ["target"] = "delegated" }, "child-recorded"))
        {
            Tools = tools,
            MaxSteps = 3,
            AllowedTools = new List<string> { "record" },
            Policy = new ChildPolicy(),
        };
        return new Agent(options);
    }

    private sealed class ChildPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("child generation");
            if (action.Kind == "tool.invoke")
            {
                return action.ToolName == "record"
                    ? Decision.Allow("child may only record")
                    : Decision.Deny("child may only record");
            }
            return Decision.Deny("unsupported action");
        }
    }

    private static Agent BuildParent(RecordTool record)
    {
        var tools = new ToolRegistry();
        tools.Register(new DelegateTool(record));
        tools.Register(new ParentOnlyTool());
        var options = new AgentOptions(
            new FixtureModel(
                "delegate",
                new JsonObject { ["task"] = "record the delegated result" },
                "parent-done"))
        {
            Tools = tools,
            MaxSteps = 3,
            AllowedTools = new List<string> { "delegate", "parent_only" },
            Policy = new ParentPolicy(),
        };
        return new Agent(options);
    }

    private sealed class ParentPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("parent generation");
            if (action.Kind == "tool.invoke")
            {
                return action.ToolName is "delegate" or "parent_only"
                    ? Decision.Allow("parent may delegate but not record")
                    : Decision.Deny("parent may delegate but not record");
            }
            return Decision.Deny("unsupported action");
        }
    }

    public static int Main(string[] args)
    {
        if (args.Contains("--governance"))
        {
            return GovernanceSelfTest.Run();
        }
        var record = new RecordTool();
        var result = BuildParent(record).Run(
            new Session("advanced-delegation-parent"),
            "Delegate the record operation to the child agent.");
        if (result.Output != "parent-done" || record.Calls != 1)
        {
            Console.Error.WriteLine(
                $"delegation failed: output={result.Output} effects={record.Calls}");
            return 1;
        }
        Console.WriteLine("delegation: child recorded; parent scope enforced");

        var direct = new ToolRegistry();
        direct.Register(record);
        var options = new AgentOptions(
            new FixtureModel("record", new JsonObject { ["target"] = "parent" }, "unexpected"))
        {
            Tools = direct,
            MaxSteps = 3,
            AllowedTools = new List<string> { "record" },
            Policy = new DirectPolicy(),
        };
        try
        {
            new Agent(options).Run(
                new Session("advanced-delegation-direct"), "Record directly.");
        }
        catch (PraxoException error)
        {
            if (error.Code != "AGENT_POLICY_DENIED" || record.Calls != 1)
            {
                Console.Error.WriteLine(
                    $"deny verification failed: code={error.Code} effects={record.Calls}");
                return 1;
            }
            Console.WriteLine("deny: parent record blocked; child effect unchanged");
            return 0;
        }

        Console.Error.WriteLine("parent recorded outside the delegated scope");
        return 1;
    }

    private sealed class DirectPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            return action.Kind == "model.generate"
                ? Decision.Allow("parent generation")
                : Decision.Deny("parent may not record");
        }
    }
}
