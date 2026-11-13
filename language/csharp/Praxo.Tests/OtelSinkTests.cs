using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tests;

internal static class OtelSinkTests
{
    public static int Run()
    {
        var calls = new List<OtelHttpRequest>();
        OtelTransport capture = request =>
        {
            calls.Add(request);
            return new OtelHttpResponse { StatusCode = 200 };
        };
        var sink = new OtelSink(
            new OtelSinkOptions
            {
                Endpoint = "http://otel.test/v1/traces",
                ServiceName = "praxo-test",
                AllowedDataKeys = new List<string> { "name" },
            },
            capture);
        sink.Emit(Event());

        Check(calls.Count == 1, "otel single request");
        var request = calls[0];
        Check(request.Method == "POST", "otel method");
        Check(request.Url == "http://otel.test/v1/traces", "otel url");
        Check(
            request.Headers["content-type"] == "application/json",
            "otel content type");
        var payload = Json.Parse(request.Body)!;
        var resourceSpan = Json.Array(Json.Get(payload, "resourceSpans"))[0]!;
        var resource = Json.Get(resourceSpan, "resource")!;
        var resourceAttributes = Json.Get(resource, "attributes")!;
        Check(
            Json.GetString(resourceAttributes[0], "key") == "service.name",
            "otel service key");
        Check(
            Json.Get(Json.Get(resourceAttributes[0], "value")!, "stringValue")!
                .GetValue<string>() == "praxo-test",
            "otel service name");
        var scopeSpan = Json.Array(Json.Get(resourceSpan, "scopeSpans"))[0]!;
        var span = Json.Array(Json.Get(scopeSpan, "spans"))[0]!;
        Check(Json.GetString(span, "name") == "praxo.tool.call", "otel span name");
        Check(Json.GetString(span, "traceId")!.Length == 32, "otel trace id");
        Check(Json.GetString(span, "spanId")!.Length == 16, "otel span id");
        Check(Json.GetString(span, "startTimeUnixNano")
            == Json.GetString(span, "endTimeUnixNano"), "otel timestamps");
        var attributes = new Dictionary<string, string>();
        foreach (var item in Json.Array(Json.Get(span, "attributes")))
        {
            attributes[Json.GetString(item, "key")!] =
                Json.Get(Json.Get(item, "value")!, "stringValue")!.GetValue<string>();
        }
        Check(attributes["praxo.event.type"] == "tool.call", "otel event type");
        Check(attributes["praxo.session.id"] == "s1", "otel session");
        Check(attributes["praxo.run.id"] == "run-123", "otel run");
        Check(attributes["praxo.event.data.name"] == "echo", "otel allowed data");
        Check(!attributes.ContainsKey("praxo.event.data.secret"), "otel data excluded");

        sink.Emit(Event());
        var second = Json.Parse(calls[1].Body)!;
        var secondResourceSpan = Json.Array(Json.Get(second, "resourceSpans"))[0]!;
        var secondScopeSpan = Json.Array(
            Json.Get(secondResourceSpan, "scopeSpans"))[0]!;
        var secondSpan = Json.Array(Json.Get(secondScopeSpan, "spans"))[0]!;
        Check(
            Json.GetString(span, "traceId") == Json.GetString(secondSpan, "traceId"),
            "otel deterministic trace");
        Check(
            Json.GetString(span, "spanId") == Json.GetString(secondSpan, "spanId"),
            "otel deterministic span");

        var failing = new OtelSink(
            new OtelSinkOptions { Endpoint = "http://otel.test/v1/traces" },
            _ => new OtelHttpResponse { StatusCode = 503, Body = "down" });
        try
        {
            failing.Emit(Event());
            throw new InvalidOperationException("expected non-2xx error");
        }
        catch (PraxoException error)
        {
            Check(error.Message.Contains("503"), "otel error status");
        }
        return 1;
    }

    private static Event Event()
    {
        var data = new JsonObject
        {
            ["name"] = "echo",
            ["secret"] = "hidden",
        };
        var item = new Event("tool.call", "s1").WithRun("run-123").WithData(data);
        item.At = "2026-11-10T07:00:00Z";
        return item;
    }

    private static void Check(bool condition, string detail)
    {
        if (!condition)
        {
            throw new InvalidOperationException(detail);
        }
    }
}
