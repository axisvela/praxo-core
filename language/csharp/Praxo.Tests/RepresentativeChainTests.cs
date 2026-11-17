using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tests;

internal static class RepresentativeChainTests
{
    private static int _passed;

    public static int Run()
    {
        _passed = 0;
        RunAcceptedChain();
        RunDenial();
        return _passed;
    }

    private static void RunAcceptedChain()
    {
        var effects = new Dictionary<string, int>(StringComparer.Ordinal);
        using var client = new McpClient(new InMemoryMcpTransport(effects));
        client.Connect();
        var record = new McpToolAdapter(
            client,
            client.ListTools().Single(tool => tool.Name == "record"));

        var spans = new List<string>();
        var envelopes = new List<string>();
        var events = new MultiSink(new IEventSink[]
        {
            new OtelSink(
                new OtelSinkOptions
                {
                    Endpoint = "http://otel.test/v1/traces",
                    ServiceName = "praxo-chain",
                },
                request =>
                {
                    spans.Add(OtelSpanName(request.Body));
                    return new OtelHttpResponse { StatusCode = 200 };
                }),
            new HarmovelaSink(
                new HarmovelaSinkOptions
                {
                    BaseUrl = "http://harmovela.test",
                    Source = "praxo-chain",
                },
                request =>
                {
                    envelopes.Add(Json.GetString(Json.Parse(request.Body), "type") ?? "");
                    return new HarmovelaHttpResponse { StatusCode = 202 };
                }),
        });

        var childModel = new ScriptedModel(
            new[]
            {
                new[]
                {
                    Call("child-record", "record", Target("child")),
                },
            },
            "CHILD-DONE");
        var parentModel = new ScriptedModel(
            new[]
            {
                new[]
                {
                    Call("parent-record", "record", Target("parent")),
                },
                new[]
                {
                    new ToolCall
                    {
                        Id = "parent-delegate",
                        Name = "delegate",
                        Arguments = new JsonObject { ["task"] = "child" },
                    },
                },
            },
            "DONE");

        var tools = new ToolRegistry();
        tools.Register(record);
        tools.Register(new DelegateTool(record, childModel, effects, events));
        var options = new AgentOptions(parentModel)
        {
            Tools = tools,
            AllowedTools = new List<string> { "record", "delegate" },
            Policy = new PolicyHook(ParentDecision),
            RequirePolicy = true,
            RequireToolScope = true,
            MaxSteps = 6,
            Events = events,
        };
        var result = new Agent(options).Run(
            new Session("chain-parent"), "run the representative chain");

        Check(result.Output == "DONE", "parent output");
        Check(effects.GetValueOrDefault("parent") == 1, "parent effects");
        Check(effects.GetValueOrDefault("child") == 1, "child effects");
        Check(childModel.Calls >= 2, "child model calls");
        foreach (var span in new[]
        {
            "praxo.run.started", "praxo.tool.call", "praxo.run.completed",
        })
        {
            Check(spans.Contains(span), $"missing span {span}");
        }
        foreach (var type in new[] { "run.started", "tool.call", "run.completed" })
        {
            Check(envelopes.Contains(type), $"missing event {type}");
        }
    }

    private static void RunDenial()
    {
        var effects = new Dictionary<string, int>(StringComparer.Ordinal);
        using var client = new McpClient(new InMemoryMcpTransport(effects));
        client.Connect();
        var record = new McpToolAdapter(
            client,
            client.ListTools().Single(tool => tool.Name == "record"));
        var tools = new ToolRegistry();
        tools.Register(record);
        var model = new ScriptedModel(
            new[]
            {
                new[] { Call("denied-record", "record", Target("safe")) },
            },
            "UNEXPECTED");
        var options = new AgentOptions(model)
        {
            Tools = tools,
            AllowedTools = new List<string> { "record" },
            Policy = new PolicyHook(ParentDecision),
            RequirePolicy = true,
            RequireToolScope = true,
            MaxSteps = 2,
        };
        options.Middleware.Add(new EditTargetMiddleware());
        try
        {
            new Agent(options).Run(new Session("chain-denial"), "call record");
            throw new InvalidOperationException("denial path unexpectedly succeeded");
        }
        catch (PraxoException error) when (error.Code == "AGENT_POLICY_DENIED")
        {
            Check(effects.GetValueOrDefault("blocked") == 0, "denied effect");
        }
    }

    private static Decision ParentDecision(Praxo.Core.Action action)
    {
        if (action.Kind == "model.generate")
        {
            return Decision.Allow("model generation");
        }
        if (action.Kind != "tool.invoke")
        {
            return Decision.Deny("unsupported action");
        }
        if (action.ToolName == "record")
        {
            return Json.GetString(action.Arguments, "target") == "blocked"
                ? Decision.Deny("blocked target")
                : Decision.Allow("record allowed");
        }
        return action.ToolName == "delegate"
            ? Decision.Allow("delegate allowed")
            : Decision.Deny("parent tool is not allowed");
    }

    private static Decision ChildDecision(Praxo.Core.Action action)
    {
        if (action.Kind == "model.generate")
        {
            return Decision.Allow("model generation");
        }
        return action.Kind == "tool.invoke" && action.ToolName == "record"
            ? Decision.Allow("child record allowed")
            : Decision.Deny("child may only record");
    }

    private static JsonObject Target(string target)
        => new() { ["target"] = target };

    private static ToolCall Call(string id, string name, JsonObject arguments)
        => new() { Id = id, Name = name, Arguments = arguments };

    private static string OtelSpanName(string body)
    {
        var payload = Json.Parse(body)!;
        var resource = Json.Array(Json.Get(payload, "resourceSpans"))[0]!;
        var scope = Json.Array(Json.Get(resource, "scopeSpans"))[0]!;
        var span = Json.Array(Json.Get(scope, "spans"))[0]!;
        return Json.GetString(span, "name") ?? "";
    }

    private static void Check(bool condition, string detail)
    {
        if (!condition)
        {
            throw new InvalidOperationException(detail);
        }
        _passed++;
    }

    private sealed class InMemoryMcpTransport : IMcpTransport
    {
        private readonly Dictionary<string, int> _effects;
        private bool _running;

        public InMemoryMcpTransport(Dictionary<string, int> effects)
        {
            _effects = effects;
        }

        public int? ProcessId => null;

        public bool HasExited => !_running;

        public void Start()
        {
            _running = true;
        }

        public void Send(JsonObject message)
        {
        }

        public void Notify(string method, JsonObject? parameters)
        {
        }

        public JsonObject Request(
            string method,
            JsonObject? parameters,
            TimeSpan timeout,
            CancellationToken cancellationToken)
        {
            if (!_running)
            {
                throw PraxoException.McpTransport("mcp: transport is closed");
            }
            var result = method switch
            {
                "initialize" => new JsonObject
                {
                    ["protocolVersion"] = McpClient.DefaultProtocolVersion,
                    ["capabilities"] = new JsonObject { ["tools"] = new JsonObject() },
                    ["serverInfo"] = new JsonObject
                    {
                        ["name"] = "chain-mcp",
                        ["version"] = "0.0.1",
                    },
                },
                "tools/list" => new JsonObject
                {
                    ["tools"] = new JsonArray
                    {
                        new JsonObject
                        {
                            ["name"] = "record",
                            ["description"] = "Record a target",
                            ["inputSchema"] = new JsonObject
                            {
                                ["type"] = "object",
                                ["properties"] = new JsonObject
                                {
                                    ["target"] = new JsonObject
                                    {
                                        ["type"] = "string",
                                    },
                                },
                                ["required"] = new JsonArray { "target" },
                            },
                        },
                    },
                },
                "tools/call" => CallTool(parameters),
                _ => throw new InvalidOperationException(
                    $"unsupported method: {method}"),
            };
            return new JsonObject
            {
                ["jsonrpc"] = "2.0",
                ["id"] = 1,
                ["result"] = result,
            };
        }

        public void Close()
        {
            _running = false;
        }

        public void Dispose() => Close();

        private JsonObject CallTool(JsonObject? parameters)
        {
            var name = Json.GetString(parameters, "name");
            if (name != "record")
            {
                return new JsonObject
                {
                    ["isError"] = true,
                    ["content"] = new JsonArray
                    {
                        new JsonObject
                        {
                            ["type"] = "text",
                            ["text"] = "unknown tool",
                        },
                    },
                };
            }
            var arguments = Json.Object(parameters?["arguments"]);
            var target = Json.GetString(arguments, "target") ?? "";
            _effects[target] = _effects.GetValueOrDefault(target) + 1;
            return new JsonObject
            {
                ["content"] = new JsonArray
                {
                    new JsonObject
                    {
                        ["type"] = "text",
                        ["text"] = $"recorded:{target}",
                    },
                },
            };
        }
    }

    private sealed class ScriptedModel : IModel
    {
        private readonly IReadOnlyList<IReadOnlyList<ToolCall>> _steps;
        private readonly string _completion;
        private int _index;

        public ScriptedModel(
            IReadOnlyList<IReadOnlyList<ToolCall>> steps,
            string completion)
        {
            _steps = steps;
            _completion = completion;
        }

        public int Calls { get; private set; }

        public Response Generate(Request request)
        {
            Calls++;
            if (_index < _steps.Count)
            {
                return new Response
                {
                    Message = Message.Assistant("", _steps[_index++]),
                };
            }
            return new Response { Message = Message.Assistant(_completion) };
        }
    }

    private sealed class PolicyHook : IPolicyHook
    {
        private readonly Func<Praxo.Core.Action, Decision> _authorize;

        public PolicyHook(Func<Praxo.Core.Action, Decision> authorize)
        {
            _authorize = authorize;
        }

        public Decision Authorize(Praxo.Core.Action action) => _authorize(action);
    }

    private sealed class ComposedPolicy : IPolicyHook
    {
        private readonly IReadOnlyList<IPolicyHook> _hooks;

        public ComposedPolicy(params IPolicyHook[] hooks)
        {
            _hooks = hooks;
        }

        public Decision Authorize(Praxo.Core.Action action)
        {
            foreach (var hook in _hooks)
            {
                var decision = hook.Authorize(action);
                if (!decision.Allowed)
                {
                    return decision;
                }
            }
            return Decision.Allow("delegation policy chain allowed");
        }
    }

    private sealed class DelegateTool : ITool
    {
        private readonly ITool _record;
        private readonly ScriptedModel _childModel;
        private readonly Dictionary<string, int> _effects;
        private readonly IEventSink _events;

        public DelegateTool(
            ITool record,
            ScriptedModel childModel,
            Dictionary<string, int> effects,
            IEventSink events)
        {
            _record = record;
            _childModel = childModel;
            _effects = effects;
            _events = events;
        }

        public string Name => "delegate";

        public string Description =>
            "Run a governed child agent with the narrowed record scope";

        public JsonNode? Invoke(JsonObject arguments)
        {
            var registry = new ToolRegistry();
            registry.Register(_record);
            var options = new AgentOptions(_childModel)
            {
                Tools = registry,
                AllowedTools = new List<string> { "record" },
                Policy = new ComposedPolicy(
                    new PolicyHook(ParentDecision),
                    new PolicyHook(ChildDecision)),
                RequirePolicy = true,
                RequireToolScope = true,
                MaxSteps = 3,
                Events = _events,
            };
            var result = new Agent(options).Run(
                new Session("chain-child"), "record child");
            return new JsonObject
            {
                ["output"] = result.Output,
                ["effects"] = _effects.GetValueOrDefault("child"),
            };
        }
    }

    private sealed class EditTargetMiddleware : IMiddleware
    {
        public void BeforeTool(MiddlewareToolCall call)
        {
            call.Call.Arguments["target"] = "blocked";
        }
    }
}
