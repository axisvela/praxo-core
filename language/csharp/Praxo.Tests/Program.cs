using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tests;

internal static class Program
{
    private static int _passed;

    public static int Main(string[] args)
    {
        if (args.Contains("--fake-mcp-server"))
        {
            return FakeMcpServer.Run(args);
        }
        TestToolCallJson();
        TestToolCallStrip();
        TestJsonSchema();
        TestContextEstimate();
        TestContextCompaction();
        TestMemoryOrdering();
        TestCheckpointAllowlist();
        TestPiiRedaction();
        TestCallLimit();
        TestCapacityFailClosed();
        TestPluginValidation();
        TestPolicy();
        TestAgentDirect();
        TestAgentToolLoop();
        TestFinalArguments();
        TestFinalName();
        TestUnchangedSingleAuthorization();
        TestInitialDenial();
        TestHitl();
        TestStartupCleanup();
        TestAfterRunContinues();
        TestCleanupFailClosed();
        TestOpenAiStreamCompletion();
        TestOpenAiStreamTruncated();
        TestOpenAiStreamHalfPacket();
        _passed += ProviderAdapterTests.Run();
        HarmovelaSinkTests.Run();
        TestParallelTools();
        TestModelCancellation();
        TestToolCancellation();
        TestStreamCallbackFailure();
        _passed += McpTests.Run();
        _passed += McpHttpTests.Run();
        Console.WriteLine($"C# core tests passed ({_passed})");
        return 0;
    }

    private static void TestToolCallJson()
    {
        var call = ToolCallParser.Parse("{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}");
        Check(call != null, "json tool call");
        Check(call!.Name == "echo", "tool name");
        Check(call.Input["text"]?.GetValue<string>() == "hi", "tool input");
    }

    private static void TestToolCallStrip()
    {
        var text = ToolCallParser.StripMarkup(
            "hello<tool_call name=\"echo\">{\"text\":\"hi\"}</tool_call>world");
        Check(text == "helloworld", "strip markup");
    }

    private static void TestJsonSchema()
    {
        var schema = Json.Parse("{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}");
        var errors = JsonSchema.Validate(schema, new JsonObject());
        Check(errors.Count == 1 && errors[0].Path == "$.name", "schema required path");
        Check(JsonSchema.Validate(schema, new JsonObject { ["name"] = "ok" }).Count == 0, "schema valid");
        var unicodeSchema = Json.Parse("{\"type\":\"string\",\"minLength\":2,\"maxLength\":2}");
        Check(JsonSchema.Validate(unicodeSchema, JsonValue.Create("你好")).Count == 0, "schema unicode two");
        Check(JsonSchema.Validate(unicodeSchema, JsonValue.Create("你")).Count == 1, "schema unicode one");
        var integerSchema = Json.Parse("{\"type\":\"integer\"}");
        Check(JsonSchema.Validate(integerSchema, JsonValue.Create(2.0)).Count == 0, "schema integer");
        Check(JsonSchema.Validate(integerSchema, JsonValue.Create(2.5)).Count == 1, "schema integer fraction");
    }

    private static void TestContextEstimate()
    {
        var messages = new List<Message>
        {
            Message.Text(Roles.System, "sys"),
            Message.Text(Roles.User, "message 0"),
            Message.Text(Roles.User, "message 1"),
        };
        Check(ContextEstimator.EstimateTokens(messages) == 16, "context estimate");
    }

    private static void TestContextCompaction()
    {
        var messages = new List<Message> { Message.Text(Roles.System, "sys") };
        for (var index = 0; index < 10; index++)
        {
            messages.Add(Message.Text(Roles.User, $"message {index}"));
        }
        var (output, ok) = new ContextBudget(30, 2).Compact(messages);
        Check(ok, "compact ok");
        Check(ContextEstimator.EstimateTokens(output) == 25, "compact tokens");
        Check(output.Count == 3, "compact size");
    }

    private static void TestMemoryOrdering()
    {
        var store = new InMemoryMemoryStore();
        store.Put("s1", new MemoryRecord { Id = "m1", Content = "Alpha", CreatedAt = "2026-01-01T00:00:00Z" });
        store.Put("s1", new MemoryRecord { Id = "m2", Content = "beta", CreatedAt = "2026-01-02T00:00:00Z" });
        var found = store.Search("s1", "alpha", 10);
        Check(found.Count == 1 && found[0].Id == "m1", "memory search");
    }

    private static void TestCheckpointAllowlist()
    {
        var allow = new CheckpointAllowlist();
        allow.Register("spec.payload");
        var encoded = allow.Marshal("spec.payload", new JsonObject { ["value"] = "x" });
        var decoded = allow.Unmarshal(encoded);
        Check(decoded?["value"]?.GetValue<string>() == "x", "checkpoint roundtrip");
        var rejected = false;
        try
        {
            allow.Marshal("spec.missing", new JsonObject());
        }
        catch (PraxoException ex) when (ex.Code == "CHECKPOINT_TYPE_NOT_ALLOWED")
        {
            rejected = true;
        }
        Check(rejected, "checkpoint rejects unregistered");
    }

    private static void TestPiiRedaction()
    {
        Check(PiiRedactor.Defaults().Redact("email a@b.com") == "email [REDACTED:email]", "pii redaction");

        var original = new JsonObject
        {
            ["email"] = "a@b.com",
            ["nested"] = new JsonObject { ["ssn"] = "123-45-6789" },
        };
        var request = Request.Of(new[]
        {
            new Message
            {
                Role = "assistant",
                ToolCalls = new List<ToolCall>
                {
                    new() { Id = "call-1", Name = "lookup", Arguments = original },
                },
            },
        });
        var call = new ModelCall { RunId = "r1", SessionId = "s1", Request = request };
        new PiiMiddleware(PiiRedactor.Defaults()).BeforeModel(call);
        var redacted = call.Request.Messages[0].ToolCalls[0].Arguments;
        Check(redacted["email"]?.GetValue<string>() == "[REDACTED:email]", "pii tool-call email");
        Check(
            (redacted["nested"] as JsonObject)?["ssn"]?.GetValue<string>() == "[REDACTED:ssn]",
            "pii nested tool-call ssn");
        Check(original["email"]?.GetValue<string>() == "a@b.com", "pii caller arguments unchanged");
    }

    private static void TestCallLimit()
    {
        var modelLimit = new CallLimitMiddleware(1, 0);
        var modelCall = new ModelCall { RunId = "r1" };
        modelLimit.BeforeModel(modelCall);
        var rejected = false;
        try
        {
            modelLimit.BeforeModel(modelCall);
        }
        catch (PraxoException ex) when (ex.Code == "AGENT_MODEL_CALL_LIMIT")
        {
            rejected = true;
        }
        Check(rejected, "model call limit");

        var toolLimit = new CallLimitMiddleware(0, 1);
        var toolCall = new MiddlewareToolCall { RunId = "r2" };
        toolLimit.BeforeTool(toolCall);
        rejected = false;
        try
        {
            toolLimit.BeforeTool(toolCall);
        }
        catch (PraxoException ex) when (ex.Code == "AGENT_TOOL_CALL_LIMIT")
        {
            rejected = true;
        }
        Check(rejected, "tool call limit");

        var isolated = new CallLimitMiddleware(1, 0);
        var first = new ModelCall { RunId = "run-1" };
        var second = new ModelCall { RunId = "run-2" };
        isolated.BeforeModel(first);
        isolated.BeforeModel(second);
        rejected = false;
        try
        {
            isolated.BeforeModel(first);
        }
        catch (PraxoException ex) when (ex.Code == "AGENT_MODEL_CALL_LIMIT")
        {
            rejected = true;
        }
        Check(rejected, "call limit state is isolated by run");
    }

    private static void TestCapacityFailClosed()
    {
        var options = new AgentOptions(new StaticModel("done"))
        {
            SystemPrompt = new string('x', 1000),
            Context = new ContextBudget(10, 0),
        };
        var rejected = false;
        try
        {
            new Agent(options).Run(new Session("s1"), "go");
        }
        catch (PraxoException ex) when (ex.Code == "AGENT_CONTEXT_BUDGET")
        {
            rejected = true;
        }
        Check(rejected, "capacity fail closed");
    }

    private static void TestPluginValidation()
    {
        var manifest = Plugin.ParseManifest(
            "{\"schemaVersion\":1,\"id\":\"com.example.echo\",\"version\":\"1.0.0\",\"kind\":\"tool.provider.v1\",\"entrypoint\":{\"type\":\"process\",\"command\":\"echo\"},\"protocol\":\"jsonrpc-2\",\"capabilities\":[],\"permissions\":{},\"limits\":{},\"health\":{},\"isolation\":\"process\"}");
        Check(manifest.Id == "com.example.echo", "plugin manifest");
    }

    private static void TestPolicy()
    {
        var root = Path.Combine(Path.GetTempPath(), $"praxo-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(root);
        try
        {
            var allowedRoot = Path.Combine(root, "root");
            var outside = Path.Combine(root, "outside");
            Directory.CreateDirectory(allowedRoot);
            Directory.CreateDirectory(outside);
            var checker = new PathChecker(new[] { new PathGrant { Root = allowedRoot, Access = "readwrite" } });
            Check(checker.Check(Path.Combine(allowedRoot, "a.txt"), "read").Allowed, "policy allows inside");
            Check(!checker.Check(Path.Combine(root, "root-evil", "x.txt"), "read").Allowed, "policy denies sibling");
            Check(!checker.Check(Path.Combine(outside, "x.txt"), "read").Allowed, "policy denies outside");
        }
        finally
        {
            Directory.Delete(root, true);
        }
    }

    private static void TestAgentDirect()
    {
        var model = new StaticModel("hello");
        var agent = new Agent(new AgentOptions(model));
        var result = agent.Run(new Session("s1"), "hello");
        Check(result.Output == "hello" && result.Steps == 1, "agent direct answer");
    }

    private static void TestAgentToolLoop()
    {
        var calls = 0;
        var registry = new ToolRegistry();
        registry.Register(new FuncTool("echo", "Echo", args =>
        {
            calls++;
            return args.DeepClone();
        }));
        var model = new ScriptedToolModel();
        var agent = new Agent(new AgentOptions(model)
        {
            Tools = registry,
            MaxSteps = 8,
        });
        var result = agent.Run(new Session("s1"), "use the tool");
        Check(result.Output == "done" && result.Steps == 2 && calls == 1, "agent tool loop");
    }

    private static void TestFinalArguments()
    {
        var invoked = new List<JsonObject>();
        var registry = new ToolRegistry();
        registry.Register(new FuncTool("echo", "Echo", args =>
        {
            invoked.Add((JsonObject)args.DeepClone());
            return args.DeepClone();
        }));
        var policy = new RecordingPolicy();
        var middleware = new MutatingMiddleware
        {
            Mutate = call => call.Call.Arguments = new JsonObject { ["text"] = "mutated" },
        };
        var options = new AgentOptions(new ScriptedToolModel())
        {
            Tools = registry,
            Policy = policy,
        };
        options.Middleware.Add(middleware);
        var result = new Agent(options).Run(new Session("s1"), "go");
        var toolActions = policy.Actions.Where(action => action.Kind == "tool.invoke").ToList();
        Check(result.Output == "done" && invoked.Count == 1, "final arguments effect");
        Check(toolActions.Count == 2, "final arguments reauthorized");
        Check(toolActions[0].Arguments?["text"]?.GetValue<string>() == "hi", "original arguments authorized");
        Check(toolActions[1].Arguments?["text"]?.GetValue<string>() == "mutated", "final arguments authorized");
        Check(invoked[0]["text"]?.GetValue<string>() == "mutated", "final arguments invoked");
    }

    private static void TestFinalName()
    {
        var echoCalls = 0;
        var otherCalls = 0;
        var registry = new ToolRegistry();
        registry.Register(new FuncTool("echo", "Echo", args => { echoCalls++; return args.DeepClone(); }));
        registry.Register(new FuncTool("other", "Other", args => { otherCalls++; return args.DeepClone(); }));
        var policy = new RecordingPolicy();
        var middleware = new MutatingMiddleware
        {
            Mutate = call => call.Call.Name = "other",
        };
        var options = new AgentOptions(new ScriptedToolModel())
        {
            Tools = registry,
            Policy = policy,
        };
        options.Middleware.Add(middleware);
        new Agent(options).Run(new Session("s1"), "go");
        var toolActions = policy.Actions.Where(action => action.Kind == "tool.invoke").ToList();
        Check(echoCalls == 0 && otherCalls == 1, "final name uses final tool");
        Check(toolActions.Count == 2
            && toolActions[0].ToolName == "echo"
            && toolActions[1].ToolName == "other", "final name authorized");

        var deniedCalls = 0;
        var deniedRegistry = new ToolRegistry();
        deniedRegistry.Register(new FuncTool("echo", "Echo", args => args.DeepClone()));
        deniedRegistry.Register(new FuncTool("other", "Other", args =>
        {
            deniedCalls++;
            return args.DeepClone();
        }));
        var deniedMiddleware = new MutatingMiddleware
        {
            Mutate = call => call.Call.Name = "other",
        };
        var deniedOptions = new AgentOptions(new ScriptedToolModel())
        {
            Tools = deniedRegistry,
            AllowedTools = new List<string> { "echo" },
        };
        deniedOptions.Middleware.Add(deniedMiddleware);
        var denied = false;
        try
        {
            new Agent(deniedOptions).Run(new Session("s1"), "go");
        }
        catch (PraxoException ex) when (ex.Code == "AGENT_TOOL_NOT_ALLOWED")
        {
            denied = true;
        }
        Check(denied && deniedCalls == 0, "final name checks allowlist");
    }

    private static void TestUnchangedSingleAuthorization()
    {
        var registry = new ToolRegistry();
        registry.Register(new FuncTool("echo", "Echo", args => args.DeepClone()));
        var policy = new RecordingPolicy();
        var middleware = new MutatingMiddleware();
        var options = new AgentOptions(new ScriptedToolModel())
        {
            Tools = registry,
            Policy = policy,
        };
        options.Middleware.Add(middleware);
        new Agent(options).Run(new Session("s1"), "go");
        var toolActions = policy.Actions.Where(action => action.Kind == "tool.invoke").ToList();
        Check(toolActions.Count == 1, "unchanged call authorized once");
    }

    private static void TestInitialDenial()
    {
        var toolCalls = 0;
        var registry = new ToolRegistry();
        registry.Register(new FuncTool("echo", "Echo", args =>
        {
            toolCalls++;
            return args.DeepClone();
        }));
        var policy = new RecordingPolicy
        {
            Handler = action => action.Kind == "tool.invoke"
                ? Decision.Deny("blocked")
                : Decision.Allow("ok"),
        };
        var middleware = new MutatingMiddleware();
        var options = new AgentOptions(new ScriptedToolModel())
        {
            Tools = registry,
            Policy = policy,
        };
        options.Middleware.Add(middleware);
        var denied = false;
        try
        {
            new Agent(options).Run(new Session("s1"), "go");
        }
        catch (PraxoException ex) when (ex.Code == "AGENT_POLICY_DENIED")
        {
            denied = true;
        }
        Check(denied && middleware.BeforeToolCalls == 0 && toolCalls == 0,
            "initial denial prevents middleware and effect");
    }

    private static void TestHitl()
    {
        var calls = 0;
        var registry = new ToolRegistry();
        registry.Register(new FuncTool("echo", "Echo", args =>
        {
            calls++;
            return args.DeepClone();
        }));
        var options = new AgentOptions(new ScriptedToolModel())
        {
            Tools = registry,
            OnInterruptDecision = new HitlHandler(_ => new InterruptDecision
            {
                Action = InterruptAction.Approve,
            }),
        };
        options.InterruptOn.Add("echo");
        var result = new Agent(options).Run(new Session("s1"), "go");
        Check(result.Output == "done" && calls == 1,
            "hitl approve runs the tool");

        calls = 0;
        var policy = new RecordingPolicy();
        var editOptions = new AgentOptions(new ScriptedToolModel())
        {
            Tools = registry,
            Policy = policy,
            OnInterruptDecision = new HitlHandler(_ => new InterruptDecision
            {
                Action = InterruptAction.Edit,
                Arguments = new JsonObject { ["value"] = "edited" },
            }),
        };
        editOptions.InterruptOn.Add("echo");
        new Agent(editOptions).Run(new Session("s1"), "go");
        var toolActions = policy.Actions.Where(action => action.Kind == "tool.invoke").ToList();
        Check(calls == 1 && toolActions.Count == 2,
            "hitl edit reauthorizes final arguments");

        calls = 0;
        var rejected = false;
        var rejectOptions = new AgentOptions(new ScriptedToolModel())
        {
            Tools = registry,
            OnInterruptDecision = new HitlHandler(_ => new InterruptDecision
            {
                Action = InterruptAction.Reject,
                Reason = "not allowed",
            }),
        };
        rejectOptions.InterruptOn.Add("echo");
        try
        {
            new Agent(rejectOptions).Run(new Session("s1"), "go");
        }
        catch (PraxoException ex) when (ex.Code == "AGENT_APPROVAL_DENIED")
        {
            rejected = true;
        }
        Check(rejected && calls == 0, "hitl reject prevents effects");

        var unhandled = false;
        var unhandledOptions = new AgentOptions(new ScriptedToolModel())
        {
            Tools = registry,
        };
        unhandledOptions.InterruptOn.Add("echo");
        try
        {
            new Agent(unhandledOptions).Run(new Session("s1"), "go");
        }
        catch (PraxoException ex) when (ex.Code == "AGENT_INTERRUPT_UNHANDLED")
        {
            unhandled = true;
        }
        Check(unhandled && calls == 0, "hitl requires a handler");

        var sink = new RecordingSink();
        var eventOptions = new AgentOptions(new ScriptedToolModel())
        {
            Tools = registry,
            Events = sink,
            OnInterruptDecision = new HitlHandler(_ => new InterruptDecision
            {
                Action = InterruptAction.Approve,
            }),
        };
        eventOptions.InterruptOn.Add("echo");
        new Agent(eventOptions).Run(new Session("s1"), "go");
        Check(sink.Events.Count(item => item.Type == "tool.interrupt") == 1,
            "hitl emits tool.interrupt");
    }

    private static void TestStartupCleanup()
    {
        var calls = new List<string>();
        var sink = new RecordingSink();
        var first = new LifecycleMiddleware
        {
            Before = () => calls.Add("first.before"),
            After = (_, _) => calls.Add("first.after"),
        };
        var second = new LifecycleMiddleware
        {
            Before = () =>
            {
                calls.Add("second.before");
                throw new PraxoException("STARTUP_FAILED", "startup failed");
            },
            After = (_, _) => calls.Add("second.after"),
        };
        var third = new LifecycleMiddleware
        {
            Before = () => calls.Add("third.before"),
            After = (_, _) => calls.Add("third.after"),
        };
        var options = new AgentOptions(new StaticTestModel()) { Events = sink };
        options.Middleware.Add(first);
        options.Middleware.Add(second);
        options.Middleware.Add(third);
        var failure = "";
        try
        {
            new Agent(options).Run(new Session("s1"), "go");
        }
        catch (PraxoException ex) when (ex.Code == "STARTUP_FAILED")
        {
            failure = ex.Message;
        }
        Check(failure == "startup failed", "startup failure preserved");
        Check(calls.SequenceEqual(new[]
        {
            "first.before", "second.before", "first.after", "second.after",
        }), "startup cleanup order");
        Check(sink.Events.Count == 0, "startup emits no run events");
    }

    private static void TestAfterRunContinues()
    {
        var calls = new List<string>();
        var first = new LifecycleMiddleware
        {
            After = (_, _) =>
            {
                calls.Add("first.after");
                throw new PraxoException("CLEANUP_FAILED", "cleanup failed");
            },
        };
        var second = new LifecycleMiddleware
        {
            After = (_, _) => calls.Add("second.after"),
        };
        var options = new AgentOptions(new FailingTestModel("run failed"));
        options.Middleware.Add(first);
        options.Middleware.Add(second);
        var failure = "";
        try
        {
            new Agent(options).Run(new Session("s1"), "go");
        }
        catch (PraxoException ex) when (ex.Code == "RUN_FAILED")
        {
            failure = ex.Message;
        }
        Check(failure == "run failed", "run error preserved");
        Check(calls.SequenceEqual(new[] { "first.after", "second.after" }),
            "after-run continues after a failure");
    }

    private static void TestCleanupFailClosed()
    {
        var calls = new List<string>();
        var sink = new RecordingSink();
        var first = new LifecycleMiddleware
        {
            After = (_, _) =>
            {
                calls.Add("first.after");
                throw new PraxoException("CLEANUP_FAILED", "cleanup failed");
            },
        };
        var second = new LifecycleMiddleware
        {
            After = (_, _) => calls.Add("second.after"),
        };
        var options = new AgentOptions(new StaticTestModel()) { Events = sink };
        options.Middleware.Add(first);
        options.Middleware.Add(second);
        var failure = "";
        try
        {
            new Agent(options).Run(new Session("s1"), "go");
        }
        catch (PraxoException ex) when (ex.Code == "CLEANUP_FAILED")
        {
            failure = ex.Message;
        }
        Check(failure == "cleanup failed", "cleanup error fails closed");
        Check(calls.SequenceEqual(new[] { "first.after", "second.after" }),
            "cleanup continues after a failure");
        Check(sink.Events.Select(item => item.Type)
            .SequenceEqual(new[] { "run.started", "run.failed" }),
            "cleanup failure emits failed");
    }

    private static void TestOpenAiStreamCompletion()
    {
        var body = "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n" +
            "data: [DONE]\n\n";
        var deltas = new List<string>();
        var response = StreamModel(body).GenerateStream(
            new Request
            {
                Messages = new List<Message> { Message.Text(Roles.User, "hi") },
            },
            deltas.Add);
        Check(response.Message.Content == "hi", "stream content");
        Check(deltas.SequenceEqual(new[] { "hi" }), "stream deltas");
    }

    private static void TestOpenAiStreamTruncated()
    {
        var body = "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n";
        var rejected = false;
        try
        {
            StreamModel(body).GenerateStream(
                new Request
                {
                    Messages = new List<Message> { Message.Text(Roles.User, "hi") },
                },
                _ => { });
        }
        catch (PraxoException ex) when (ex.Code == "MODEL_STREAM")
        {
            rejected = true;
        }
        Check(rejected, "truncated stream rejected");
    }

    private static void TestOpenAiStreamHalfPacket()
    {
        var body = "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n" +
            "data: {\"choices\"";
        var rejected = false;
        try
        {
            StreamModel(body).GenerateStream(
                new Request
                {
                    Messages = new List<Message> { Message.Text(Roles.User, "hi") },
                },
                _ => { });
        }
        catch (PraxoException ex) when (ex.Code == "MODEL_STREAM")
        {
            rejected = true;
        }
        Check(rejected, "half-packet stream rejected");
    }

    private static void TestParallelTools()
    {
        var started = new CountdownEvent(2);
        var registry = new ToolRegistry();
        registry.Register(new FuncTool("a", "A", args =>
        {
            started.Signal();
            if (!started.Wait(TimeSpan.FromSeconds(2)))
            {
                throw new InvalidOperationException("tools did not start concurrently");
            }
            Thread.Sleep(100);
            return new JsonObject { ["name"] = "a" };
        }));
        registry.Register(new FuncTool("b", "B", args =>
        {
            started.Signal();
            if (!started.Wait(TimeSpan.FromSeconds(2)))
            {
                throw new InvalidOperationException("tools did not start concurrently");
            }
            return new JsonObject { ["name"] = "b" };
        }));
        var model = new ParallelToolModel();
        var options = new AgentOptions(model)
        {
            Tools = registry,
            MaxParallelTools = 2,
        };
        var result = new Agent(options).Run(new Session("s1"), "go");
        Check(result.Output == "done", "parallel run completed");
        var names = model.SecondRequestMessages?
            .Where(message => message.Role == Roles.Tool)
            .Select(message => Json.Parse(message.Content ?? "{}")?["name"]?.GetValue<string>())
            .ToList();
        Check(names != null && names.SequenceEqual(new[] { "a", "b" }),
            "parallel results keep order");
    }

    private static void TestModelCancellation()
    {
        var cts = new CancellationTokenSource();
        var calls = new List<string>();
        var sink = new RecordingSink();
        var middleware = new LifecycleMiddleware
        {
            After = (_, _) => calls.Add("after"),
        };
        var options = new AgentOptions(new CancellingModel(cts))
        {
            CancellationToken = cts.Token,
            Events = sink,
        };
        options.Middleware.Add(middleware);
        var cancelled = false;
        try
        {
            new Agent(options).Run(new Session("s1"), "go");
        }
        catch (OperationCanceledException)
        {
            cancelled = true;
        }
        Check(cancelled, "model cancellation propagated");
        Check(calls.SequenceEqual(new[] { "after" }), "model cancellation runs after-run");
        Check(sink.Events.Select(item => item.Type)
            .SequenceEqual(new[] { "run.started", "run.failed" }),
            "model cancellation emits failed");
    }

    private static void TestToolCancellation()
    {
        var cts = new CancellationTokenSource();
        var effectCalls = 0;
        var calls = new List<string>();
        var registry = new ToolRegistry();
        registry.Register(new FuncTool("cancel", "Cancel", args =>
        {
            cts.Cancel();
            return new JsonObject();
        }));
        registry.Register(new FuncTool("effect", "Effect", args =>
        {
            effectCalls++;
            return new JsonObject();
        }));
        var middleware = new LifecycleMiddleware
        {
            After = (_, _) => calls.Add("after"),
        };
        var options = new AgentOptions(new CancellationToolModel())
        {
            Tools = registry,
            MaxParallelTools = 1,
            CancellationToken = cts.Token,
        };
        options.Middleware.Add(middleware);
        var cancelled = false;
        try
        {
            new Agent(options).Run(new Session("s1"), "go");
        }
        catch (OperationCanceledException)
        {
            cancelled = true;
        }
        Check(cancelled, "tool cancellation propagated");
        Check(effectCalls == 0, "tool cancellation stops later effects");
        Check(calls.SequenceEqual(new[] { "after" }), "tool cancellation runs after-run");
    }

    private static void TestStreamCallbackFailure()
    {
        var calls = new List<string>();
        var sink = new RecordingSink();
        var middleware = new LifecycleMiddleware
        {
            After = (_, _) => calls.Add("after"),
        };
        var options = new AgentOptions(new StreamCallbackModel())
        {
            Events = sink,
        };
        options.Middleware.Add(middleware);
        var failed = false;
        try
        {
            new Agent(options).RunStream(
                new Session("s1"),
                "go",
                _ => throw new PraxoException("CALLBACK", "callback failed"));
        }
        catch (PraxoException ex) when (ex.Code == "CALLBACK")
        {
            failed = true;
        }
        Check(failed, "stream callback failure propagated");
        Check(calls.SequenceEqual(new[] { "after" }), "stream failure runs after-run");
        Check(sink.Events.Select(item => item.Type)
            .SequenceEqual(new[] { "run.started", "run.failed" }),
            "stream failure emits failed");
    }

    private static OpenAiCompatibleModel StreamModel(string body)
        => new(
            new HttpClient(new StubHandler(body)),
            new OpenAiCompatibleOptions
            {
                BaseUrl = "http://localhost/v1",
                Model = "test",
            });

    private static void Check(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message);
        }
        _passed++;
    }

    private sealed class StubHandler : HttpMessageHandler
    {
        private readonly string _body;

        public StubHandler(string body)
        {
            _body = body;
        }

        protected override HttpResponseMessage Send(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
            => new(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    _body,
                    Encoding.UTF8,
                    "text/event-stream"),
            };

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
            => Task.FromResult(Send(request, cancellationToken));
    }

    private sealed class LifecycleMiddleware : IMiddleware
    {
        public System.Action? Before { get; init; }

        public System.Action<RunResult?, PraxoException?>? After { get; init; }

        public void BeforeRun(RunState state)
        {
            Before?.Invoke();
        }

        public void AfterRun(RunResult? result, PraxoException? error)
        {
            After?.Invoke(result, error);
        }
    }

    private sealed class RecordingSink : IEventSink
    {
        public List<Event> Events { get; } = new();

        public void Emit(Event @event)
        {
            Events.Add(@event);
        }
    }

    private sealed class StaticTestModel : IModel
    {
        public Response Generate(Request request)
            => new() { Message = Message.Assistant("done") };
    }

    private sealed class FailingTestModel : IModel
    {
        private readonly string _message;

        public FailingTestModel(string message)
        {
            _message = message;
        }

        public Response Generate(Request request)
            => throw new PraxoException("RUN_FAILED", _message);
    }

    private sealed class CancellingModel : IModel
    {
        private readonly CancellationTokenSource _cts;

        public CancellingModel(CancellationTokenSource cts)
        {
            _cts = cts;
        }

        public Response Generate(Request request)
        {
            _cts.Cancel();
            return new Response { Message = Message.Assistant("done") };
        }
    }

    private sealed class CancellationToolModel : IModel
    {
        private int _step;

        public Response Generate(Request request)
        {
            if (_step++ == 0)
            {
                return new Response
                {
                    Message = Message.Assistant("", new[]
                    {
                        new ToolCall
                        {
                            Id = "c1",
                            Name = "cancel",
                            Arguments = new JsonObject(),
                        },
                        new ToolCall
                        {
                            Id = "c2",
                            Name = "effect",
                            Arguments = new JsonObject(),
                        },
                    }),
                };
            }
            return new Response { Message = Message.Assistant("done") };
        }
    }

    private sealed class StreamCallbackModel : IModel, IStreamingModel
    {
        public Response Generate(Request request)
            => new() { Message = Message.Assistant("done") };

        public Response GenerateStream(Request request, Action<string> onDelta)
        {
            onDelta("x");
            return new Response { Message = Message.Assistant("done") };
        }
    }

    private sealed class ParallelToolModel : IModel
    {
        private int _step;

        public IReadOnlyList<Message>? SecondRequestMessages { get; private set; }

        public Response Generate(Request request)
        {
            if (_step++ == 0)
            {
                return new Response
                {
                    Message = Message.Assistant("", new[]
                    {
                        new ToolCall
                        {
                            Id = "a1",
                            Name = "a",
                            Arguments = new JsonObject(),
                        },
                        new ToolCall
                        {
                            Id = "b1",
                            Name = "b",
                            Arguments = new JsonObject(),
                        },
                    }),
                };
            }
            SecondRequestMessages = request.Messages;
            return new Response { Message = Message.Assistant("done") };
        }
    }

    private sealed class ScriptedToolModel : IModel
    {
        private int _step;

        public Response Generate(Request request)
        {
            if (_step++ == 0)
            {
                return new Response
                {
                    Message = Message.Assistant("", new[]
                    {
                        new ToolCall { Id = "c1", Name = "echo", Arguments = new JsonObject { ["text"] = "hi" } },
                    }),
                };
            }
            return new Response { Message = Message.Assistant("done") };
        }
    }

    private sealed class HitlHandler : IInterruptHandler
    {
        private readonly Func<Interrupt, InterruptDecision> _handler;

        public HitlHandler(Func<Interrupt, InterruptDecision> handler)
        {
            _handler = handler;
        }

        public InterruptDecision Decide(Interrupt interrupt)
            => _handler(interrupt);
    }

    private sealed class RecordingPolicy : IPolicyHook
    {
        public List<Praxo.Core.Action> Actions { get; } = new();

        public Func<Praxo.Core.Action, Decision>? Handler { get; set; }

        public Decision Authorize(Praxo.Core.Action action)
        {
            Actions.Add(new Praxo.Core.Action
            {
                Kind = action.Kind,
                SessionId = action.SessionId,
                ToolName = action.ToolName,
                Arguments = (JsonObject?)action.Arguments?.DeepClone(),
            });
            return Handler?.Invoke(action) ?? Decision.Allow("ok");
        }
    }

    private sealed class MutatingMiddleware : IMiddleware
    {
        public Action<MiddlewareToolCall>? Mutate { get; set; }

        public int BeforeToolCalls { get; private set; }

        public void BeforeTool(MiddlewareToolCall call)
        {
            BeforeToolCalls++;
            Mutate?.Invoke(call);
        }
    }
}
