using System.Text.Json;
using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Conformance;

internal static class VectorRunners
{
    public static void Run(string group, JsonNode vector)
    {
        switch (group)
        {
            case "toolcall":
                RunToolcall(vector);
                break;
            case "jsonschema":
                RunJsonSchema(vector);
                break;
            case "plugin":
                RunPlugin(vector);
                break;
            case "memory":
                RunMemory(vector);
                break;
            case "event":
                RunEvent(vector);
                break;
            case "stream":
                RunStream(vector);
                break;
            case "checkpoint":
                RunCheckpoint(vector);
                break;
            case "policy":
                RunPolicy(vector);
                break;
            case "context":
                RunContext(vector);
                break;
            case "middleware":
                MiddlewareVectors.Run(vector);
                break;
            case "agent-loop":
                RunAgentLoop(vector);
                break;
            default:
                throw new ConformanceException($"no runner for group {group}");
        }
    }

    private static void RunToolcall(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        var operation = Json.GetString(input, "operation") ?? "";
        var content = Json.GetString(input, "content") ?? "";
        if (operation == "strip")
        {
            var got = ToolCallParser.StripMarkup(content);
            Assert.True(got == (Json.GetString(expect, "text") ?? ""), $"strip: got {got}");
            return;
        }
        var call = ToolCallParser.Parse(content);
        if (Json.GetBool(expect, "nil"))
        {
            Assert.True(call == null, "expected nil");
            return;
        }
        Assert.True(call != null, "expected a tool call");
        Assert.True(call!.Name == (Json.GetString(expect, "name") ?? ""), $"name: got {call.Name}");
        var expected = Json.Get(expect, "input") as JsonObject ?? new JsonObject();
        Assert.True(Json.DeepEquals(call.Input, expected), "input mismatch");
    }

    private static void RunJsonSchema(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        var errors = JsonSchema.Validate(Json.Get(input, "schema"), Json.Get(input, "data"));
        var paths = errors.Select(error => error.Path).OrderBy(path => path, StringComparer.Ordinal).ToList();
        var want = Json.Array(Json.Get(expect, "errorPaths"))
            .Select(item => item is JsonValue value && value.TryGetValue<string>(out var text) ? text : null)
            .Where(text => text != null)
            .Select(text => text!)
            .OrderBy(text => text, StringComparer.Ordinal)
            .ToList();
        Assert.True(errors.Count == 0 == Json.GetBool(expect, "valid"), "valid mismatch");
        Assert.True(paths.SequenceEqual(want), $"errorPaths: got [{string.Join(", ", paths)}]");
    }

    private static void RunPlugin(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        var raw = Json.GetString(input, "raw") ?? Json.Stringify(Json.Get(input, "manifest"));
        PluginManifest? manifest;
        try
        {
            manifest = Plugin.ParseManifest(raw);
        }
        catch (PraxoException)
        {
            manifest = null;
        }
        Assert.True(manifest != null == Json.GetBool(expect, "valid"), "valid mismatch");
        if (manifest == null)
        {
            return;
        }
        if (Json.GetString(expect, "id") is { } id)
        {
            Assert.True(manifest.Id == id, $"id: got {manifest.Id}");
        }
        if (Json.GetString(expect, "kind") is { } kind)
        {
            Assert.True(manifest.Kind == kind, $"kind: got {manifest.Kind}");
        }
    }

    private static void RunMemory(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        var store = new InMemoryMemoryStore();
        foreach (var put in Json.Array(Json.Get(input, "puts")))
        {
            var session = Json.GetString(put, "session") ?? "";
            var record = JsonSerializer.Deserialize<MemoryRecord>(
                Json.Stringify(Json.Get(put, "record")), Json.Options)
                ?? throw new ConformanceException("invalid memory record");
            store.Put(session, record);
        }
        var records = store.Search(
            Json.GetString(input, "session") ?? "",
            Json.GetString(input, "query") ?? "",
            Json.GetInt(input, "limit"));
        var ids = records.Select(record => record.Id).ToList();
        var contents = records.Select(record => record.Content).ToList();
        Assert.True(Json.DeepEquals(Normalize(ids), Json.Get(expect, "ids")), "ids mismatch");
        Assert.True(Json.DeepEquals(Normalize(contents), Json.Get(expect, "contents")), "contents mismatch");
    }

    private static void RunEvent(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        var events = Json.Array(Json.Get(input, "events"))
            .Select(item => new Event(
                item is JsonValue value && value.TryGetValue<string>(out var text) ? text : "", "s1"))
            .ToList();
        if (Json.GetString(input, "sink") == "multi")
        {
            var count = Math.Max(1, Json.GetInt(input, "sinkCount", 1));
            var sinks = Enumerable.Range(0, count).Select(_ => new RecordingSink()).ToList();
            var multi = new MultiSink(sinks);
            foreach (var @event in events)
            {
                multi.Emit(@event);
            }
            var perSink = new JsonArray(sinks
                .Select(sink => (JsonNode)new JsonArray(sink.Types
                    .Select(type => (JsonNode?)JsonValue.Create(type)).ToArray()))
                .ToArray());
            Assert.True(Json.DeepEquals(perSink, Json.Get(expect, "perSink")), "perSink mismatch");
            return;
        }
        var sink = new RecordingSink();
        HashSet<string>? allowed = null;
        if (Json.Get(input, "predicateTypes") is JsonArray predicate)
        {
            allowed = predicate
                .Select(item => item is JsonValue value && value.TryGetValue<string>(out var text) ? text : null)
                .Where(text => text != null)
                .Select(text => text!)
                .ToHashSet(StringComparer.Ordinal);
        }
        var filter = new FilterSink(sink, @event => allowed == null || allowed.Contains(@event.Type));
        foreach (var @event in events)
        {
            filter.Emit(@event);
        }
        Assert.True(Json.DeepEquals(Normalize(sink.Types), Json.Get(expect, "delivered")), "delivered mismatch");
    }

    private static void RunStream(JsonNode vector)
    {
        var expect = Json.Get(vector, "expect");
        var kinds = new JsonArray(StreamKinds.All
            .Select(kind => (JsonNode?)JsonValue.Create(kind)).ToArray());
        Assert.True(Json.DeepEquals(kinds, Json.Get(expect, "kinds")), "kinds mismatch");
    }

    private static void RunCheckpoint(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        var allow = new CheckpointAllowlist();
        foreach (var item in Json.Array(Json.Get(input, "registered")))
        {
            allow.Register(item is JsonValue scalar && scalar.TryGetValue<string>(out var text) ? text : "");
        }
        var operation = Json.GetString(input, "operation") ?? "roundtrip";
        var type = Json.GetString(input, "type") ?? "";
        var payload = Json.Get(input, "value")?.DeepClone();
        if (operation == "roundtrip")
        {
            var data = allow.Marshal(type, payload);
            var got = allow.Unmarshal(data);
            Assert.True(Json.DeepEquals(got, Json.Get(expect, "value")), "value mismatch");
            return;
        }
        try
        {
            if (operation == "marshal")
            {
                allow.Marshal(type, payload);
            }
            else if (operation == "unmarshal")
            {
                var envelope = new JsonObject { ["type"] = type, ["data"] = payload };
                allow.Unmarshal(Json.Stringify(envelope));
            }
            else
            {
                throw new ConformanceException("CHECKPOINT_ERROR");
            }
            Assert.True(Json.Get(expect, "errorCode") == null, "expected an error");
        }
        catch (PraxoException ex)
        {
            Assert.True(ex.Code == (Json.GetString(expect, "errorCode") ?? ""), $"errorCode: got {ex.Code}");
        }
    }

    private static void RunPolicy(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        var root = Path.Combine(Path.GetTempPath(), $"praxo-policy-{Guid.NewGuid():N}");
        Directory.CreateDirectory(root);
        try
        {
            foreach (var dir in Json.Array(Json.Get(input, "makeDirs")))
            {
                var name = dir is JsonValue value && value.TryGetValue<string>(out var text) ? text : "";
                Directory.CreateDirectory(Path.Combine(root, name));
            }
            var grants = new List<PathGrant>();
            foreach (var item in Json.Array(Json.Get(input, "grants")))
            {
                var grantRoot = Path.Combine(root, Json.GetString(item, "root") ?? "");
                Directory.CreateDirectory(grantRoot);
                grants.Add(new PathGrant
                {
                    Root = grantRoot,
                    Access = Json.GetString(item, "access") ?? "read",
                });
            }
            var checker = new PathChecker(grants);
            var target = Path.Combine(root, Json.GetString(input, "target") ?? "");
            var need = Json.GetString(input, "need") ?? "read";
            if (Json.GetBool(expect, "error"))
            {
                try
                {
                    checker.Check(target, need);
                    throw new ConformanceException("expected a policy error");
                }
                catch (PraxoException ex) when (ex.Code == "POLICY_ERROR")
                {
                    return;
                }
            }
            var allowed = checker.Check(target, need).Allowed;
            Assert.True(allowed == Json.GetBool(expect, "allowed"), $"allowed: got {allowed}");
        }
        finally
        {
            try
            {
                Directory.Delete(root, true);
            }
            catch (IOException)
            {
            }
        }
    }

    private static void RunContext(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        var messages = new List<Message>();
        foreach (var item in Json.Array(Json.Get(input, "messages")))
        {
            messages.Add(JsonSerializer.Deserialize<Message>(Json.Stringify(item), Json.Options)
                ?? throw new ConformanceException("invalid message"));
        }
        if (Json.GetString(input, "operation") == "estimate")
        {
            var tokens = ContextEstimator.EstimateTokens(messages);
            Assert.True(tokens == Json.GetInt(expect, "tokens"), $"tokens: got {tokens}");
            return;
        }
        var budget = new ContextBudget(
            Json.GetInt(Json.Get(input, "budget"), "maxTokens"),
            Json.GetInt(Json.Get(input, "budget"), "keepRecent"));
        var (output, ok) = budget.Compact(messages);
        Assert.True(ok == Json.GetBool(expect, "ok"), $"ok: got {ok}");
        if (!ok)
        {
            return;
        }
        var tokensOut = ContextEstimator.EstimateTokens(output);
        Assert.True(tokensOut == Json.GetInt(expect, "tokens"), $"tokens: got {tokensOut}");
        var wire = new JsonArray(output.Select(message => (JsonNode?)WireMessage(message)).ToArray());
        Assert.True(Json.DeepEquals(wire, Json.Get(expect, "messages")), "messages mismatch");
    }

    private static void RunAgentLoop(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        var script = Json.Get(input, "script") as JsonArray ?? new JsonArray();
        var invocations = 0;
        var registry = new ToolRegistry();
        foreach (var tool in Json.Array(Json.Get(input, "tools")))
        {
            registry.Register(new EchoTool(
                Json.GetString(tool, "name") ?? "",
                Json.GetString(tool, "description") ?? "",
                () => invocations++));
        }
        var sink = new RecordingSink();
        var options = new AgentOptions(new ScriptedModel(script))
        {
            Tools = registry,
            Events = sink,
            MaxSteps = Json.GetInt(input, "maxSteps"),
            MaxTokens = Json.GetInt(input, "maxTokens"),
        };
        var agent = new Agent(options);
        RunResult? result = null;
        PraxoException? failure = null;
        try
        {
            result = agent.Run(new Session("s1"), Json.GetString(input, "prompt") ?? "");
        }
        catch (PraxoException ex)
        {
            failure = ex;
        }
        if (Json.GetBool(expect, "error"))
        {
            Assert.True(failure != null, "unexpected success");
            if (Json.GetString(expect, "errorCode") is { } code)
            {
                Assert.True(failure!.Code == code, $"errorCode: got {failure.Code}");
            }
        }
        else
        {
            Assert.True(failure == null, failure?.Message ?? "unexpected failure");
            Assert.True(result!.Output == (Json.GetString(expect, "output") ?? ""),
                $"output: got {result.Output}");
            Assert.True(result.Steps == Json.GetInt(expect, "steps"), $"steps: got {result.Steps}");
        }
        Assert.True(invocations == Json.GetInt(expect, "toolInvocations"),
            $"tool invocations: got {invocations}");
        Assert.True(Json.DeepEquals(Normalize(sink.Types), Json.Get(expect, "events")), "events mismatch");
    }

    private static JsonNode WireMessage(Message message)
    {
        var obj = new JsonObject { ["role"] = message.Role };
        if (message.Content != null)
        {
            obj["content"] = message.Content;
        }
        if (message.ContentBlocks.Count > 0)
        {
            obj["contentBlocks"] = Json.From(message.ContentBlocks);
        }
        if (message.ToolCalls.Count > 0)
        {
            obj["toolCalls"] = Json.From(message.ToolCalls);
        }
        if (message.ToolId != null)
        {
            obj["toolId"] = message.ToolId;
        }
        return obj;
    }

    private static JsonNode? Normalize(IEnumerable<string> values)
    {
        var list = values.ToList();
        return list.Count == 0
            ? null
            : new JsonArray(list.Select(value => (JsonNode?)JsonValue.Create(value)).ToArray());
    }
}
