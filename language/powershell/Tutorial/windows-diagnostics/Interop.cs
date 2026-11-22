#nullable enable
using System;
using System.Linq;
using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tutorial.Operations
{
    public sealed class FixtureModel : IModel
    {
        private readonly string _service;

        public FixtureModel(string service) { _service = service; }

        public Response Generate(Request request)
        {
            var results = request.Messages.Where(message => message.Role == Roles.Tool).ToArray();
            if (results.Length == 2)
            {
                var checks = new JsonArray();
                foreach (var result in results) checks.Add(JsonNode.Parse(result.Content!));
                return new Response { Message = Message.Assistant(
                    new JsonObject { ["checks"] = checks, ["mutating_tools_registered"] = false }.ToJsonString()) };
            }
            bool service = results.Length == 0;
            return new Response
            {
                Message = Message.Assistant("", new[]
                {
                    new ToolCall
                    {
                        Id = service ? "service-1" : "disk-1",
                        Name = service ? "read_service" : "read_disk",
                        Arguments = new JsonObject { ["name"] = service ? _service : "system" },
                    },
                }),
            };
        }
    }

    public sealed class ScopePolicy : IPolicyHook
    {
        public Decision Authorize(Praxo.Core.Action action)
        {
            if (action.Kind == "model.generate") return Decision.Allow("fixture model");
            if (action.Kind != "tool.invoke") return Decision.Deny("unsupported action");
            string? name = action.Arguments?["name"]?.GetValue<string>();
            return (action.ToolName == "read_service" && name == "Spooler")
                || (action.ToolName == "read_disk" && name == "system")
                ? Decision.Allow("read-only resource scope") : Decision.Deny("resource outside diagnostic scope");
        }
    }

    public sealed class ProbeTool : ITool, IToolSpecProvider
    {
        private readonly string _resource;
        private readonly Func<JsonObject, JsonNode?> _read;
        public string Name { get; }
        public string Description => "Read one fixed diagnostic resource; no command execution or repairs.";
        public int Calls { get; private set; }

        public ProbeTool(string name, string resource, Func<JsonObject, JsonNode?> read)
        {
            Name = name;
            _resource = resource;
            _read = read;
        }

        public JsonNode? Invoke(JsonObject arguments)
        {
            if (arguments["name"]?.GetValue<string>() != _resource)
                throw new ArgumentException("Diagnostic resource not allowed");
            Calls++;
            return _read(arguments);
        }

        public ToolSpec Spec() => new ToolSpec
        {
            Name = Name, Description = Description, Risk = "read",
            Parameters = JsonNode.Parse("""
                {"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}
                """)!.AsObject(),
        };
    }
}
