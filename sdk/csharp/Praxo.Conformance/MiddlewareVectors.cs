using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Conformance;

internal static class MiddlewareVectors
{
    public static void Run(JsonNode vector)
    {
        var input = Json.Get(vector, "input");
        var expect = Json.Get(vector, "expect");
        switch (Json.GetString(input, "operation"))
        {
            case "pii":
            {
                var got = PiiRedactor.Defaults().Redact(Json.GetString(input, "text") ?? "");
                Assert.True(got == (Json.GetString(expect, "text") ?? ""), $"text: got {got}");
                return;
            }
            case "pii-value":
            {
                var middleware = new PiiMiddleware(PiiRedactor.Defaults());
                var result = new ToolResult { Value = Json.Get(input, "value")?.DeepClone() };
                middleware.AfterTool(new MiddlewareToolCall(), result);
                Assert.True(Json.DeepEquals(result.Value, Json.Get(expect, "value")), "value mismatch");
                return;
            }
            case "structured":
            {
                var output = new StructuredOutput(
                    Json.Get(input, "schema") as JsonObject ?? new JsonObject(),
                    maxRepairs: Json.GetInt(input, "maxRepairs"));
                if (Json.GetString(input, "repairOutput") is { } repair)
                {
                    output.Repairer = (_, _) => repair;
                }
                var result = new RunResult { RunId = "r1", Output = Json.GetString(input, "output") ?? "" };
                try
                {
                    output.Apply(result);
                    Assert.True(Json.GetBool(expect, "ok"), "expected a structured output error");
                    Assert.True(result.Output == (Json.GetString(expect, "output") ?? ""),
                        $"output: got {result.Output}");
                }
                catch (PraxoException ex)
                {
                    Assert.True(!Json.GetBool(expect, "ok"), ex.Message);
                    Assert.True(ex.Code == (Json.GetString(expect, "errorCode") ?? ""),
                        $"errorCode: got {ex.Code}");
                }
                return;
            }
            case "call-limit":
            {
                var middleware = new CallLimitMiddleware(
                    Json.GetInt(input, "modelLimit"), Json.GetInt(input, "toolLimit"));
                middleware.BeforeRun(new RunState { RunId = "r1" });
                var outcomes = new List<string>();
                foreach (var item in Json.Array(Json.Get(input, "calls")))
                {
                    var kind = item is JsonValue value && value.TryGetValue<string>(out var text) ? text : "";
                    try
                    {
                        if (kind == "model")
                        {
                            middleware.BeforeModel(new ModelCall { RunId = "r1" });
                        }
                        else
                        {
                            middleware.BeforeTool(new MiddlewareToolCall
                            {
                                RunId = "r1",
                                Call = new ToolCall { Name = "echo" },
                            });
                        }
                        outcomes.Add("ok");
                    }
                    catch (PraxoException ex)
                    {
                        outcomes.Add(ex.Code);
                    }
                }
                var expected = Json.Array(Json.Get(expect, "outcomes"))
                    .Select(item => item?.GetValue<string>() ?? "").ToList();
                Assert.True(outcomes.SequenceEqual(expected), "outcomes mismatch");
                return;
            }
            case "tool-selection":
            {
                var selected = Json.Array(Json.Get(input, "selected"))
                    .Select(item => item?.GetValue<string>() ?? "").ToList();
                var middleware = new ToolSelectionMiddleware(new FixedSelector(selected));
                var tools = Json.Array(Json.Get(input, "tools"))
                    .Select(item => new ToolSpec { Name = item?.GetValue<string>() ?? "" }).ToList();
                var call = new ModelCall
                {
                    RunId = "r1",
                    Request = new Request { Tools = tools },
                };
                middleware.BeforeModel(call);
                var advertised = call.Request.Tools.Select(spec => spec.Name).ToList();
                var expected = Json.Array(Json.Get(expect, "advertised"))
                    .Select(item => item?.GetValue<string>() ?? "").ToList();
                Assert.True(advertised.SequenceEqual(expected), "advertised mismatch");
                var requested = Json.GetString(input, "requested") ?? "";
                string reject;
                try
                {
                    middleware.BeforeTool(new MiddlewareToolCall
                    {
                        RunId = "r1",
                        Call = new ToolCall { Name = requested },
                    });
                    reject = "ok";
                }
                catch (PraxoException ex)
                {
                    reject = ex.Code;
                }
                Assert.True(reject == (Json.GetString(expect, "reject") ?? ""), $"reject: got {reject}");
                return;
            }
            case "fallback":
            {
                var content = Json.GetString(input, "fallbackContent") ?? "";
                var handler = ModelFallback.FallbackWithContent(content)(
                    _ => throw new PraxoException("PRIMARY_FAILED", "primary failed"));
                var response = handler(new Request());
                Assert.True(response.Message.Content == content, "output mismatch");
                return;
            }
            default:
                throw new ConformanceException("unknown middleware operation");
        }
    }

}
