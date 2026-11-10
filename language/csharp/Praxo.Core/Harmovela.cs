using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class HarmovelaSinkOptions
{
    public string BaseUrl { get; set; } = "";

    public string Source { get; set; } = "praxo-core";

    public string SpecVersion { get; set; } = "0.2";

    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(30);
}

public sealed class HarmovelaHttpRequest
{
    public string Method { get; set; } = "POST";

    public string Url { get; set; } = "";

    public Dictionary<string, string> Headers { get; set; } = new();

    public string Body { get; set; } = "";
}

public sealed class HarmovelaHttpResponse
{
    public int StatusCode { get; set; }

    public string Body { get; set; } = "";
}

public delegate HarmovelaHttpResponse HarmovelaTransport(HarmovelaHttpRequest request);

public sealed class HarmovelaSink : IEventSink
{
    private readonly HarmovelaSinkOptions _options;
    private readonly HarmovelaTransport _transport;
    private readonly HttpClient _client;

    public HarmovelaSink(HarmovelaSinkOptions options)
        : this(options, null)
    {
    }

    public HarmovelaSink(HarmovelaSinkOptions options, HarmovelaTransport? transport)
    {
        _options = options;
        _client = new HttpClient { Timeout = options.Timeout };
        _transport = transport ?? Send;
    }

    public void Emit(Event @event)
    {
        var baseUrl = (_options.BaseUrl ?? "").TrimEnd('/');
        if (baseUrl.Length == 0)
        {
            throw new PraxoException("HARMOVELA_BASE_URL", "harmovela: base URL is required");
        }
        var at = InstantOf(@event.At);
        var payload = @event.Data == null
            ? new JsonObject()
            : (JsonObject)@event.Data.DeepClone();
        if (!string.IsNullOrEmpty(@event.SessionId))
        {
            payload["session_id"] = @event.SessionId;
        }
        if (!string.IsNullOrEmpty(@event.RunId))
        {
            payload["run_id"] = @event.RunId;
        }
        var envelope = new JsonObject
        {
            ["spec_version"] = string.IsNullOrEmpty(_options.SpecVersion) ? "0.2" : _options.SpecVersion,
            ["id"] = EventId(@event, at),
            ["type"] = @event.Type,
            ["source"] = string.IsNullOrEmpty(_options.Source) ? "praxo-core" : _options.Source,
            ["created_at"] = Rfc3339Nanos(at),
            ["payload"] = payload,
        };
        var request = new HarmovelaHttpRequest
        {
            Method = "POST",
            Url = baseUrl + "/events",
            Headers = new Dictionary<string, string>
            {
                ["content-type"] = "application/json",
            },
            Body = Json.Stringify(envelope),
        };
        var response = _transport(request);
        if (response.StatusCode < 200 || response.StatusCode >= 300)
        {
            var text = response.Body ?? "";
            if (text.Length > 512)
            {
                text = text[..512];
            }
            throw new PraxoException(
                "HARMOVELA_HTTP",
                $"harmovela: HTTP {response.StatusCode}: {text.Trim()}");
        }
    }

    private HarmovelaHttpResponse Send(HarmovelaHttpRequest request)
    {
        using var message = new HttpRequestMessage(
            new HttpMethod(request.Method),
            request.Url);
        message.Content = new StringContent(request.Body, Encoding.UTF8);
        message.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
        using var response = _client.Send(message);
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        return new HarmovelaHttpResponse
        {
            StatusCode = (int)response.StatusCode,
            Body = body,
        };
    }

    private static DateTimeOffset InstantOf(string? raw)
    {
        if (!string.IsNullOrEmpty(raw)
            && DateTimeOffset.TryParse(
                raw,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                out var at))
        {
            return at.ToUniversalTime();
        }
        return DateTimeOffset.UtcNow;
    }

    private static string EventId(Event @event, DateTimeOffset at)
    {
        var prefix = !string.IsNullOrEmpty(@event.RunId)
            ? @event.RunId
            : !string.IsNullOrEmpty(@event.SessionId) ? @event.SessionId : "event";
        var nanos = at.UtcTicks % TimeSpan.TicksPerSecond * 100;
        return $"{prefix}-{at.ToUnixTimeSeconds() * 1_000_000_000L + nanos}";
    }

    private static string Rfc3339Nanos(DateTimeOffset at)
    {
        var utc = at.ToUniversalTime();
        var seconds = utc.ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture);
        var nanos = utc.UtcTicks % TimeSpan.TicksPerSecond;
        return $"{seconds}.{nanos:D7}00Z";
    }
}
