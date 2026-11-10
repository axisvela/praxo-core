using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.Tests;

internal static class HarmovelaSinkTests
{
    public static void Run()
    {
        var calls = new List<HarmovelaHttpRequest>();
        HarmovelaTransport capture = request =>
        {
            calls.Add(request);
            return new HarmovelaHttpResponse { StatusCode = 201 };
        };
        var sink = new HarmovelaSink(
            new HarmovelaSinkOptions { BaseUrl = "http://harmovela.test/aep/api/" },
            capture);
        sink.Emit(Event());

        Check(calls.Count == 1, "harmovela single request");
        var request = calls[0];
        Check(request.Method == "POST", "harmovela method");
        Check(request.Url == "http://harmovela.test/aep/api/events", "harmovela path");
        Check(request.Headers["content-type"] == "application/json", "harmovela content type");
        var envelope = Json.Parse(request.Body)!;
        Check(Json.GetString(envelope, "spec_version") == "0.2", "harmovela spec");
        Check(Json.GetString(envelope, "id") == "run-123-1794294000000000000", "harmovela id");
        Check(Json.GetString(envelope, "type") == "tool.call", "harmovela type");
        Check(Json.GetString(envelope, "source") == "praxo-core", "harmovela source");
        Check(
            Json.GetString(envelope, "created_at") == "2026-11-10T07:00:00.000000000Z",
            "harmovela created_at");
        var payload = Json.Get(envelope, "payload");
        Check(Json.GetString(payload, "name") == "echo", "harmovela payload data");
        Check(Json.GetString(payload, "session_id") == "s1", "harmovela payload session");
        Check(Json.GetString(payload, "run_id") == "run-123", "harmovela payload run");

        var custom = new HarmovelaSink(
            new HarmovelaSinkOptions
            {
                BaseUrl = "http://harmovela.test",
                Source = "custom",
                SpecVersion = "0.3",
            },
            capture);
        var data = new JsonObject
        {
            ["name"] = "echo",
            ["session_id"] = "event-side",
            ["run_id"] = "old",
        };
        var merged = new Event("tool.call", "s1").WithData(data);
        merged.At = "2026-11-10T07:00:00Z";
        custom.Emit(merged);
        var mergedEnvelope = Json.Parse(calls[1].Body)!;
        Check(Json.GetString(mergedEnvelope, "source") == "custom", "harmovela custom source");
        Check(Json.GetString(mergedEnvelope, "spec_version") == "0.3", "harmovela custom spec");
        Check(Json.GetString(mergedEnvelope, "id")!.StartsWith("s1-"), "harmovela session id");
        var mergedPayload = Json.Get(mergedEnvelope, "payload");
        Check(Json.GetString(mergedPayload, "session_id") == "s1", "harmovela session override");
        Check(Json.GetString(mergedPayload, "run_id") == "old", "harmovela data run retained");

        foreach (var status in new[] { 200, 201, 204, 299 })
        {
            var accepted = new HarmovelaSink(
                new HarmovelaSinkOptions { BaseUrl = "http://harmovela.test" },
                _ => new HarmovelaHttpResponse { StatusCode = status });
            accepted.Emit(Event());
        }

        var failing = new HarmovelaSink(
            new HarmovelaSinkOptions { BaseUrl = "http://harmovela.test" },
            _ => new HarmovelaHttpResponse
            {
                StatusCode = 503,
                Body = string.Concat(Enumerable.Repeat("service down ", 100)),
            });
        try
        {
            failing.Emit(Event());
            throw new InvalidOperationException("expected non-2xx error");
        }
        catch (PraxoException error) when (error.Code == "HARMOVELA_HTTP")
        {
            Check(error.Message.Contains("503"), "harmovela error status");
            Check(error.Message.Contains("service down"), "harmovela error body");
            Check(error.Message.Length <= 600, "harmovela bounded error");
        }
    }

    private static Event Event()
    {
        var @event = new Event("tool.call", "s1")
            .WithRun("run-123")
            .WithData(new JsonObject { ["name"] = "echo" });
        @event.At = "2026-11-10T07:00:00Z";
        return @event;
    }

    private static void Check(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message);
        }
    }
}
