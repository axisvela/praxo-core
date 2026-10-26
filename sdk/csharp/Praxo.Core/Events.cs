using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class Event
{
    public string Type { get; set; } = "";

    public string SessionId { get; set; } = "";

    public string? RunId { get; set; }

    public JsonObject? Data { get; set; }

    public string? At { get; set; }

    public Event(string type, string sessionId)
    {
        Type = type;
        SessionId = sessionId;
    }

    public Event WithRun(string runId)
    {
        RunId = runId;
        return this;
    }

    public Event WithData(JsonObject data)
    {
        Data = data;
        return this;
    }
}

public interface IEventSink
{
    void Emit(Event @event);
}

public sealed class MultiSink : IEventSink
{
    private readonly IReadOnlyList<IEventSink> _sinks;

    public MultiSink(IEnumerable<IEventSink> sinks)
    {
        _sinks = sinks.ToList();
    }

    public void Emit(Event @event)
    {
        foreach (var sink in _sinks)
        {
            sink.Emit(@event);
        }
    }
}

public sealed class FilterSink : IEventSink
{
    private readonly IEventSink _sink;
    private readonly Func<Event, bool> _predicate;

    public FilterSink(IEventSink sink, Func<Event, bool> predicate)
    {
        _sink = sink;
        _predicate = predicate;
    }

    public void Emit(Event @event)
    {
        if (_predicate(@event))
        {
            _sink.Emit(@event);
        }
    }
}

public static class Clock
{
    public static string NowIso()
        => DateTimeOffset.UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'");
}
