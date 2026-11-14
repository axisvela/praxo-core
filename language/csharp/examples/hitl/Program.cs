using System.Text.Json.Nodes;

using Praxo.Core;
using PraxoAction = Praxo.Core.Action;

namespace Praxo.Hitl;

public static class Program
{
    private sealed class FixtureModel : IModel
    {
        public Response Generate(Request request)
        {
            var last = request.Messages[^1];
            if (last.Role == Roles.Tool)
            {
                return new Response { Message = Message.Assistant("done") };
            }
            return new Response
            {
                Message = Message.Assistant("", new[]
                {
                    new ToolCall
                    {
                        Id = "write-note-1",
                        Name = "write_note",
                        Arguments = new JsonObject
                        {
                            ["text"] = "hello",
                            ["visibility"] = "public",
                        },
                    },
                }),
            };
        }
    }

    private sealed class WriteNoteTool : ITool, IToolSpecProvider
    {
        public List<string> Notes { get; } = new();

        public string Name => "write_note";

        public string Description => "Write a short note with the requested visibility.";

        public JsonNode? Invoke(JsonObject arguments)
        {
            Notes.Add(arguments["text"]?.GetValue<string>() ?? "");
            return JsonValue.Create("written");
        }

        public ToolSpec Spec() => new()
        {
            Name = Name,
            Description = Description,
            Parameters = JsonNode.Parse("""
                {
                  "type": "object",
                  "required": ["text", "visibility"],
                  "properties": {
                    "text": {"type": "string"},
                    "visibility": {"type": "string", "enum": ["public", "private"]}
                  }
                }
                """)!.AsObject(),
            Risk = "write",
        };
    }

    private sealed class PublicNotesPolicy : IPolicyHook
    {
        public Decision Authorize(PraxoAction action)
        {
            if (action.Kind == "model.generate")
            {
                return Decision.Allow("model generation");
            }
            if (action.Kind == "tool.invoke")
            {
                var visibility = action.Arguments?["visibility"]?.GetValue<string>();
                return action.ToolName == "write_note" && visibility == "public"
                    ? Decision.Allow("only public notes are permitted")
                    : Decision.Deny("only public notes are permitted");
            }
            return Decision.Deny("unsupported action");
        }
    }

    private sealed class FixedDecision : IInterruptHandler
    {
        private readonly InterruptDecision _decision;

        public FixedDecision(InterruptDecision decision)
        {
            _decision = decision;
        }

        public InterruptDecision Decide(Interrupt interrupt) => _decision;
    }

    private static (Agent Agent, WriteNoteTool Tool) BuildAgent(
        InterruptDecision decision)
    {
        var tool = new WriteNoteTool();
        var tools = new ToolRegistry();
        tools.Register(tool);
        var options = new AgentOptions(new FixtureModel())
        {
            Tools = tools,
            MaxSteps = 3,
            AllowedTools = new List<string> { "write_note" },
            Policy = new PublicNotesPolicy(),
            InterruptOn = new List<string> { "write_note" },
            OnInterruptDecision = new FixedDecision(decision),
        };
        return (new Agent(options), tool);
    }

    public static int Main()
    {
        var approved = BuildAgent(new InterruptDecision
        {
            Action = InterruptAction.Approve,
        });
        var result = approved.Agent.Run(new Session("hitl-approve"), "Write a note.");
        if (result.Output != "done" || approved.Tool.Notes.Count != 1)
        {
            Console.Error.WriteLine(
                $"approve scenario failed: output={result.Output} effects={approved.Tool.Notes.Count}");
            return 1;
        }
        Console.WriteLine("approve: written; effects=1");

        var edited = BuildAgent(new InterruptDecision
        {
            Action = InterruptAction.Edit,
            Arguments = new JsonObject
            {
                ["text"] = "hello",
                ["visibility"] = "private",
            },
        });
        try
        {
            edited.Agent.Run(new Session("hitl-edit"), "Write a note.");
        }
        catch (PraxoException error)
        {
            if (error.Code != "AGENT_POLICY_DENIED" || edited.Tool.Notes.Count != 0)
            {
                Console.Error.WriteLine(
                    $"edit scenario failed: code={error.Code} effects={edited.Tool.Notes.Count}");
                return 1;
            }
            Console.WriteLine("edit: policy rejected; effects=0");
            return 0;
        }

        Console.Error.WriteLine("edited private note was not denied");
        return 1;
    }
}
