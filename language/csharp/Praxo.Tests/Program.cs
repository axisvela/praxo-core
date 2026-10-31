using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tests;

internal static class Program
{
    private static int _passed;

    public static int Main()
    {
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

    private static void Check(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message);
        }
        _passed++;
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
}
