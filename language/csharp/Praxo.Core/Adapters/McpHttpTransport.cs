using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class McpStreamableHttpOptions
{
    public string Endpoint { get; set; } = "";

    public Dictionary<string, string>? Headers { get; set; }

    public string ProtocolVersion { get; set; } = "2025-03-26";

    public HttpClient? HttpClient { get; set; }
}

public sealed class McpStreamableHttpTransport : IMcpTransport
{
    private readonly McpStreamableHttpOptions _options;
    private readonly HttpClient _http;
    private readonly bool _ownsClient;
    private long _nextId;
    private string _sessionId = "";
    private string _protocolVersion;
    private bool _started;
    private bool _closed;

    public McpStreamableHttpTransport(McpStreamableHttpOptions options)
    {
        _options = options;
        _protocolVersion = string.IsNullOrWhiteSpace(options.ProtocolVersion)
            ? "2025-03-26"
            : options.ProtocolVersion;
        if (!Uri.TryCreate(options.Endpoint, UriKind.Absolute, out var endpoint)
            || (endpoint.Scheme != Uri.UriSchemeHttps
                && endpoint.Scheme != Uri.UriSchemeHttp))
        {
            throw PraxoException.McpTransport("mcp: invalid HTTP endpoint");
        }
        if (endpoint.Scheme == Uri.UriSchemeHttp && !endpoint.IsLoopback)
        {
            throw PraxoException.McpTransport(
                "mcp: HTTP endpoint must use HTTPS");
        }
        _http = options.HttpClient ?? new HttpClient();
        _ownsClient = options.HttpClient == null;
    }

    public int? ProcessId => null;

    public bool HasExited => _closed;

    public void Start()
    {
        if (_closed)
        {
            throw PraxoException.McpClosed("mcp: client is closed");
        }
        _started = true;
    }

    public void Send(JsonObject message)
    {
        Post(message, TimeSpan.Zero, CancellationToken.None);
    }

    public void Notify(string method, JsonObject? parameters)
    {
        if (!_started || _closed)
        {
            return;
        }
        var message = new JsonObject
        {
            ["jsonrpc"] = "2.0",
            ["method"] = method,
        };
        if (parameters != null)
        {
            message["params"] = parameters.DeepClone();
        }
        Post(message, TimeSpan.Zero, CancellationToken.None);
    }

    public JsonObject Request(
        string method,
        JsonObject? parameters,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        if (_closed)
        {
            throw PraxoException.McpClosed("mcp: client is closed");
        }
        var id = Interlocked.Increment(ref _nextId);
        var message = new JsonObject
        {
            ["jsonrpc"] = "2.0",
            ["id"] = id,
            ["method"] = method,
        };
        if (parameters != null)
        {
            message["params"] = parameters.DeepClone();
        }
        var response = Post(message, timeout, cancellationToken);
        if (response == null)
        {
            throw PraxoException.McpProtocol(
                $"mcp: {method} returned no response");
        }
        return response;
    }

    public void Close()
    {
        if (_closed)
        {
            return;
        }
        _closed = true;
        if (!string.IsNullOrEmpty(_sessionId))
        {
            try
            {
                using var request = new HttpRequestMessage(
                    HttpMethod.Delete, _options.Endpoint);
                ApplyHeaders(request);
                using var response = _http.SendAsync(
                        request, HttpCompletionOption.ResponseHeadersRead)
                    .GetAwaiter()
                    .GetResult();
            }
            catch
            {
                // Session termination is best-effort.
            }
        }
        if (_ownsClient)
        {
            _http.Dispose();
        }
    }

    public void Dispose() => Close();

    private JsonObject? Post(
        JsonObject message,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Post, _options.Endpoint);
        request.Content = new StringContent(
            message.ToJsonString(), Encoding.UTF8, "application/json");
        ApplyHeaders(request);
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken);
        if (timeout > TimeSpan.Zero)
        {
            linked.CancelAfter(timeout);
        }
        HttpResponseMessage response;
        try
        {
            response = _http.SendAsync(
                    request, HttpCompletionOption.ResponseHeadersRead, linked.Token)
                .GetAwaiter()
                .GetResult();
        }
        catch (OperationCanceledException) when (
            linked.IsCancellationRequested && !cancellationToken.IsCancellationRequested)
        {
            throw PraxoException.McpTimeout(
                $"mcp: request timed out after {timeout.TotalMilliseconds}ms");
        }
        catch (HttpRequestException error)
        {
            throw PraxoException.McpTransport(
                $"mcp: HTTP transport failed: {error.Message}");
        }
        using (response)
        {
            CaptureSession(response);
            if (response.StatusCode == HttpStatusCode.Accepted
                || response.StatusCode == HttpStatusCode.NoContent)
            {
                return null;
            }
            if (!response.IsSuccessStatusCode)
            {
                var detail = ReadDetail(response);
                throw PraxoException.McpTransport(
                    $"mcp: HTTP {(int)response.StatusCode}: {detail}");
            }
            var contentType = response.Content.Headers.ContentType?.MediaType ?? "";
            if (contentType.Contains("text/event-stream", StringComparison.OrdinalIgnoreCase))
            {
                return ReadEventStream(response, linked.Token);
            }
            using var reader = new StreamReader(
                response.Content.ReadAsStream(linked.Token), Encoding.UTF8);
            var text = reader.ReadToEnd();
            return ParseObject(text);
        }
    }

    private JsonObject? ReadEventStream(
        HttpResponseMessage response,
        CancellationToken cancellationToken)
    {
        using var stream = response.Content.ReadAsStream(cancellationToken);
        using var reader = new StreamReader(stream, Encoding.UTF8);
        var data = new List<string>();
        while (true)
        {
            var line = reader.ReadLine();
            if (line == null)
            {
                break;
            }
            if (line.Length == 0)
            {
                if (data.Count > 0)
                {
                    var message = ParseObject(string.Join("\n", data));
                    data.Clear();
                    if (message != null)
                    {
                        return message;
                    }
                }
                continue;
            }
            if (line.StartsWith(':'))
            {
                continue;
            }
            if (line.StartsWith("data:", StringComparison.Ordinal))
            {
                data.Add(line[5..].TrimStart());
            }
        }
        if (data.Count > 0)
        {
            return ParseObject(string.Join("\n", data));
        }
        return null;
    }

    private JsonObject? ParseObject(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return null;
        }
        JsonNode? node;
        try
        {
            node = JsonNode.Parse(text);
        }
        catch
        {
            throw PraxoException.McpProtocol("mcp: server sent invalid JSON");
        }
        if (node is not JsonObject message)
        {
            throw PraxoException.McpProtocol(
                "mcp: server sent a non-object JSON-RPC message");
        }
        var result = message["result"] as JsonObject;
        var version = result?["protocolVersion"]?.GetValue<string>();
        if (!string.IsNullOrEmpty(version))
        {
            _protocolVersion = version;
        }
        return message;
    }

    private void ApplyHeaders(HttpRequestMessage request)
    {
        request.Headers.Accept.Add(
            new MediaTypeWithQualityHeaderValue("application/json"));
        request.Headers.Accept.Add(
            new MediaTypeWithQualityHeaderValue("text/event-stream"));
        request.Headers.TryAddWithoutValidation(
            "mcp-protocol-version", _protocolVersion);
        if (!string.IsNullOrEmpty(_sessionId))
        {
            request.Headers.TryAddWithoutValidation(
                "mcp-session-id", _sessionId);
        }
        if (_options.Headers != null)
        {
            foreach (var (key, value) in _options.Headers)
            {
                request.Headers.TryAddWithoutValidation(key, value);
            }
        }
    }

    private void CaptureSession(HttpResponseMessage response)
    {
        if (response.Headers.TryGetValues("mcp-session-id", out var values))
        {
            var value = values.FirstOrDefault();
            if (!string.IsNullOrEmpty(value))
            {
                _sessionId = value;
            }
        }
    }

    private static string ReadDetail(HttpResponseMessage response)
    {
        try
        {
            var text = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
            return text.Length > 512 ? text[..512] : text;
        }
        catch
        {
            return "";
        }
    }
}
