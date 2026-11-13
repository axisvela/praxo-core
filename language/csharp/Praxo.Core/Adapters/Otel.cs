using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class OtelSinkOptions
{
    public string Endpoint { get; set; } = "http://127.0.0.1:4318/v1/traces";

    public string ServiceName { get; set; } = "praxo-core";

    public List<string> AllowedDataKeys { get; set; } = new();

    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(30);
}

public sealed class OtelHttpRequest
{
    public string Method { get; set; } = "POST";

    public string Url { get; set; } = "";

    public Dictionary<string, string> Headers { get; set; } = new();

    public string Body { get; set; } = "";
}

public sealed class OtelHttpResponse
{
    public int StatusCode { get; set; }

    public string Body { get; set; } = "";
}

public delegate OtelHttpResponse OtelTransport(OtelHttpRequest request);

public sealed class OtelSink : IEventSink
{
    private readonly OtelSinkOptions _options;
    private readonly OtelTransport _transport;
    private readonly HttpClient _client;

    public OtelSink(OtelSinkOptions options)
        : this(options, null)
    {
    }

    public OtelSink(OtelSinkOptions options, OtelTransport? transport)
    {
        _options = options;
        _client = new HttpClient { Timeout = options.Timeout };
        _transport = transport ?? Send;
    }

    public void Emit(Event @event)
    {
        var endpoint = string.IsNullOrEmpty(_options.Endpoint)
            ? "http://127.0.0.1:4318/v1/traces"
            : _options.Endpoint;
        var serviceName = string.IsNullOrEmpty(_options.ServiceName)
            ? "praxo-core"
            : _options.ServiceName;
        var at = InstantOf(@event.At);
        var nanos = (at.ToUnixTimeMilliseconds() * 1_000_000L).ToString(
            CultureInfo.InvariantCulture);
        var stamp = at.UtcDateTime.ToString(
            "yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture);
        var data = @event.Data == null ? "{}" : Json.Stringify(@event.Data);
        var key = string.Join("|", @event.SessionId, @event.RunId ?? "",
            @event.Type, stamp, data);
        var traceId = Hex(Fnv1a(key, 0xcbf29ce484222325UL))
            + Hex(Fnv1a(key, 0x84222325cbf29ce4UL));
        var spanId = Hex(Fnv1a(key + "|span", 0x100000001b3UL));

        var attributes = new JsonArray
        {
            Attribute("praxo.event.type", @event.Type),
        };
        if (!string.IsNullOrEmpty(@event.SessionId))
        {
            attributes.Add(Attribute("praxo.session.id", @event.SessionId));
        }
        if (!string.IsNullOrEmpty(@event.RunId))
        {
            attributes.Add(Attribute("praxo.run.id", @event.RunId));
        }
        attributes.Add(Attribute("praxo.event.at", stamp));
        if (@event.Data != null)
        {
            foreach (var name in _options.AllowedDataKeys)
            {
                if (@event.Data.TryGetPropertyValue(name, out var value) && value != null)
                {
                    attributes.Add(Attribute(
                        "praxo.event.data." + name,
                        Text(value)));
                }
            }
        }

        var span = new JsonObject
        {
            ["traceId"] = traceId,
            ["spanId"] = spanId,
            ["name"] = "praxo." + @event.Type,
            ["kind"] = 1,
            ["startTimeUnixNano"] = nanos,
            ["endTimeUnixNano"] = nanos,
            ["attributes"] = attributes,
        };
        var payload = new JsonObject
        {
            ["resourceSpans"] = new JsonArray
            {
                new JsonObject
                {
                    ["resource"] = new JsonObject
                    {
                        ["attributes"] = new JsonArray
                        {
                            Attribute("service.name", serviceName),
                        },
                    },
                    ["scopeSpans"] = new JsonArray
                    {
                        new JsonObject
                        {
                            ["scope"] = new JsonObject { ["name"] = "praxo-core" },
                            ["spans"] = new JsonArray { span },
                        },
                    },
                },
            },
        };
        var request = new OtelHttpRequest
        {
            Method = "POST",
            Url = endpoint,
            Headers = new Dictionary<string, string>
            {
                ["content-type"] = "application/json",
            },
            Body = Json.Stringify(payload),
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
                "OTEL_HTTP",
                $"otel: HTTP {response.StatusCode}: {text.Trim()}");
        }
    }

    private OtelHttpResponse Send(OtelHttpRequest request)
    {
        using var message = new HttpRequestMessage(
            new HttpMethod(request.Method),
            request.Url);
        message.Content = new StringContent(request.Body, Encoding.UTF8);
        message.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
        using var response = _client.Send(message);
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        return new OtelHttpResponse
        {
            StatusCode = (int)response.StatusCode,
            Body = body,
        };
    }

    private static JsonObject Attribute(string key, string value)
        => new()
        {
            ["key"] = key,
            ["value"] = new JsonObject { ["stringValue"] = value },
        };

    private static string Text(JsonNode value)
    {
        if (value is JsonValue scalar && scalar.TryGetValue<string>(out var text))
        {
            return text;
        }
        return value.ToJsonString();
    }

    private static ulong Fnv1a(string text, ulong seed)
    {
        var value = seed;
        foreach (var current in Encoding.UTF8.GetBytes(text))
        {
            value ^= current;
            value *= 0x100000001b3UL;
        }
        return value;
    }

    private static string Hex(ulong value)
        => value.ToString("x16", CultureInfo.InvariantCulture);

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
}
