using System.Text.Json.Nodes;

using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.Consumer;

public static class Program
{
    private sealed class FixtureModel : IModel
    {
        private readonly string _target;

        public FixtureModel(string target)
        {
            _target = target;
        }

        public Response Generate(Request request)
        {
            var last = request.Messages[^1];
            if (last.Role == Roles.Tool)
            {
                return new Response { Message = Message.Assistant("recorded") };
            }
            return new Response
            {
                Message = Message.Assistant("", new[]
                {
                    new ToolCall
                    {
                        Id = "record-1",
                        Name = "record",
                        Arguments = new JsonObject { ["target"] = _target },
                    },
                }),
            };
        }
    }

    private sealed class RecordTool : ITool, IToolSpecProvider
    {
        public int Calls { get; private set; }

        public string Name => "record";

        public string Description => "Record a target in an in-memory counter.";

        public JsonNode? Invoke(JsonObject arguments)
        {
            Calls += 1;
            return JsonValue.Create("recorded");
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

    private sealed class PublicTargetPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate")
            {
                return Decision.Allow("model generation");
            }
            if (action.Kind == "tool.invoke")
            {
                var target = action.Arguments?["target"]?.GetValue<string>();
                return action.ToolName == "record" && target == "public"
                    ? Decision.Allow("only the public target is permitted")
                    : Decision.Deny("only the public target is permitted");
            }
            return Decision.Deny("unsupported action");
        }
    }

    private static (Agent Agent, RecordTool Tool) BuildAgent(string target)
    {
        var tool = new RecordTool();
        var tools = new ToolRegistry();
        tools.Register(tool);
        var options = new AgentOptions(new FixtureModel(target))
        {
            Tools = tools,
            MaxSteps = 3,
            AllowedTools = new List<string> { "record" },
            Policy = new PublicTargetPolicy(),
        };
        return (new Agent(options), tool);
    }

    public static int Main()
    {
        var allowed = BuildAgent("public");
        var result = allowed.Agent.Run(
            new Session("consumer-public"), "Record the requested target.");
        if (result.Output != "recorded" || allowed.Tool.Calls != 1)
        {
            Console.Error.WriteLine(
                $"allow verification failed: output={result.Output} effects={allowed.Tool.Calls}");
            return 1;
        }
        Console.WriteLine("allow: recorded; effects=1");

        var denied = BuildAgent("private");
        try
        {
            denied.Agent.Run(new Session("consumer-private"), "Record the requested target.");
        }
        catch (PraxoException error)
        {
            if (error.Code != "AGENT_POLICY_DENIED" || denied.Tool.Calls != 0)
            {
                Console.Error.WriteLine(
                    $"deny verification failed: code={error.Code} effects={denied.Tool.Calls}");
                return 1;
            }
            Console.WriteLine("deny: policy rejected; effects=0");
            return 0;
        }

        Console.Error.WriteLine("private target was not denied");
        return 1;
    }
}
