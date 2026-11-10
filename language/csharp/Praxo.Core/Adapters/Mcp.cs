using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class McpTool
{
    public string Name { get; init; } = "";

    public string Description { get; init; } = "";

    public string Title { get; init; } = "";

    public JsonObject InputSchema { get; init; } = new();

    public JsonObject Annotations { get; init; } = new();
}

public sealed class McpClient : IDisposable
{
    public const string DefaultProtocolVersion = "2024-11-05";

    private readonly McpStdioTransport _transport;
    private readonly TimeSpan _timeout;
    private readonly string _clientName;
    private readonly string _clientVersion;
    private readonly string _requestedProtocolVersion;
    private bool _connected;
    private bool _closed;

    public McpClient(
        McpServerOptions options,
        TimeSpan? timeout = null,
        string clientName = "praxo-core",
        string clientVersion = "0.3.0",
        string protocolVersion = DefaultProtocolVersion)
        : this(new McpStdioTransport(options), timeout, clientName, clientVersion, protocolVersion)
    {
    }

    public McpClient(
        McpStdioTransport transport,
        TimeSpan? timeout = null,
        string clientName = "praxo-core",
        string clientVersion = "0.3.0",
        string protocolVersion = DefaultProtocolVersion)
    {
        _transport = transport;
        _timeout = timeout ?? TimeSpan.FromSeconds(30);
        _clientName = string.IsNullOrWhiteSpace(clientName) ? "praxo-core" : clientName;
        _clientVersion = clientVersion;
        _requestedProtocolVersion = string.IsNullOrWhiteSpace(protocolVersion)
            ? DefaultProtocolVersion
            : protocolVersion;
    }

    public string ProtocolVersion { get; private set; } = "";

    public JsonObject ServerInfo { get; private set; } = new();

    public JsonObject ServerCapabilities { get; private set; } = new();

    public bool Connected => _connected && !_closed;

    public int? ProcessId => _transport.ProcessId;

    public McpClient Connect(CancellationToken cancellationToken = default)
    {
        if (_connected)
        {
            return this;
        }
        if (_closed)
        {
            throw PraxoException.McpClosed("mcp: client is closed");
        }
        try
        {
            _transport.Start();
            var result = Request("initialize", new JsonObject
            {
                ["protocolVersion"] = _requestedProtocolVersion,
                ["capabilities"] = new JsonObject(),
                ["clientInfo"] = new JsonObject
                {
                    ["name"] = _clientName,
                    ["version"] = _clientVersion,
                },
            }, _timeout, cancellationToken);
            var version = Json.GetString(result, "protocolVersion");
            if (string.IsNullOrEmpty(version))
            {
                throw PraxoException.McpHandshake(
                    "mcp: initialize returned no protocol version");
            }
            ProtocolVersion = version;
            ServerInfo = CloneObject(result["serverInfo"]);
            ServerCapabilities = CloneObject(result["capabilities"]);
            _transport.Notify("notifications/initialized", null);
            _connected = true;
            return this;
        }
        catch
        {
            Close();
            throw;
        }
    }

    public IReadOnlyList<McpTool> ListTools(
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        var tools = new List<McpTool>();
        var names = new HashSet<string>(StringComparer.Ordinal);
        var cursors = new HashSet<string>(StringComparer.Ordinal);
        string? cursor = null;
        while (true)
        {
            var parameters = new JsonObject();
            if (!string.IsNullOrEmpty(cursor))
            {
                parameters["cursor"] = cursor;
            }
            var result = Request(
                "tools/list",
                parameters.Count > 0 ? parameters : null,
                timeout ?? _timeout,
                cancellationToken);
            if (result["tools"] is not JsonArray rawTools)
            {
                throw PraxoException.McpProtocol("mcp: tools/list tools must be a list");
            }
            foreach (var node in rawTools)
            {
                if (node is not JsonObject item)
                {
                    throw PraxoException.McpProtocol("mcp: tool definition must be an object");
                }
                var name = Json.GetString(item, "name");
                if (string.IsNullOrEmpty(name))
                {
                    throw PraxoException.McpProtocol("mcp: tool name is required");
                }
                if (!names.Add(name))
                {
                    throw PraxoException.McpDuplicateTool($"mcp: duplicate tool {name}");
                }
                if (item["inputSchema"] is not JsonObject schema)
                {
                    throw PraxoException.McpProtocol($"mcp: missing input schema for {name}");
                }
                tools.Add(new McpTool
                {
                    Name = name,
                    Description = Json.GetString(item, "description") ?? "",
                    Title = Json.GetString(item, "title") ?? "",
                    InputSchema = (JsonObject)schema.DeepClone(),
                    Annotations = CloneObject(item["annotations"]),
                });
            }
            var nextNode = result["nextCursor"];
            if (nextNode == null)
            {
                break;
            }
            if (nextNode is not JsonValue nextValue
                || !nextValue.TryGetValue<string>(out var next))
            {
                throw PraxoException.McpProtocol("mcp: tools/list nextCursor must be a string");
            }
            if (next == "")
            {
                break;
            }
            if (!cursors.Add(next))
            {
                throw PraxoException.McpPagination("mcp: repeated tool pagination cursor");
            }
            cursor = next;
        }
        tools.Sort((left, right) => string.CompareOrdinal(left.Name, right.Name));
        return tools;
    }

    public JsonNode? CallTool(
        string name,
        JsonObject? arguments = null,
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("mcp: tool name is required", nameof(name));
        }
        var result = Request("tools/call", new JsonObject
        {
            ["name"] = name,
            ["arguments"] = (arguments ?? new JsonObject()).DeepClone(),
        }, timeout ?? _timeout, cancellationToken);
        if (Json.GetBool(result, "isError"))
        {
            throw PraxoException.McpToolError(
                $"mcp: tool {name} failed: {TextContent(result)}");
        }
        var structured = result["structuredContent"];
        if (structured != null)
        {
            return structured.DeepClone();
        }
        var texts = TextContents(result);
        if (texts.Count == 0)
        {
            return null;
        }
        if (texts.Count == 1)
        {
            return JsonValue.Create(texts[0]);
        }
        var array = new JsonArray();
        foreach (var text in texts)
        {
            array.Add(JsonValue.Create(text));
        }
        return array;
    }

    public IReadOnlyList<McpToolAdapter> RegisterTools(
        ToolRegistry registry,
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(registry);
        var adapters = new List<McpToolAdapter>();
        foreach (var tool in ListTools(timeout, cancellationToken))
        {
            var adapter = new McpToolAdapter(this, tool, timeout);
            registry.Register(adapter);
            adapters.Add(adapter);
        }
        return adapters;
    }

    public void Close()
    {
        if (_closed)
        {
            return;
        }
        _closed = true;
        _connected = false;
        _transport.Close();
    }

    public void Dispose() => Close();

    private JsonObject Request(
        string method,
        JsonObject? parameters,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var response = _transport.Request(method, parameters, timeout, cancellationToken);
        if (response["error"] is JsonObject error)
        {
            throw PraxoException.McpRpc(RpcMessage(method, error));
        }
        if (response["result"] is not JsonObject result)
        {
            throw PraxoException.McpProtocol($"mcp: {method} result must be an object");
        }
        return result;
    }

    private static string RpcMessage(string method, JsonObject error)
    {
        var message = Json.GetString(error, "message");
        if (string.IsNullOrEmpty(message))
        {
            message = $"{method} failed";
        }
        var code = error["code"];
        return code == null
            ? $"mcp: {method}: {message}"
            : $"mcp: {method}: {message} (code {Json.Stringify(code)})";
    }

    private static JsonObject CloneObject(JsonNode? node)
        => node is JsonObject value ? (JsonObject)value.DeepClone() : new JsonObject();

    private static List<string> TextContents(JsonObject result)
    {
        var texts = new List<string>();
        if (result["content"] is not JsonArray content)
        {
            return texts;
        }
        foreach (var node in content)
        {
            if (node is not JsonObject block
                || Json.GetString(block, "type") != "text")
            {
                continue;
            }
            var text = Json.GetString(block, "text");
            if (text != null)
            {
                texts.Add(text);
            }
        }
        return texts;
    }

    private static string TextContent(JsonObject result)
        => string.Join("\n", TextContents(result));
}

public sealed class McpToolAdapter : ITool, IToolSpecProvider
{
    private readonly McpClient _client;
    private readonly McpTool _tool;
    private readonly TimeSpan? _timeout;

    public McpToolAdapter(McpClient client, McpTool tool, TimeSpan? timeout = null)
    {
        _client = client;
        _tool = tool;
        _timeout = timeout;
    }

    public string Name => _tool.Name;

    public string Description => _tool.Description;

    public JsonObject Parameters => _tool.InputSchema;

    public JsonNode? Invoke(JsonObject arguments) => _client.CallTool(Name, arguments, _timeout);

    public ToolSpec Spec() => new()
    {
        Name = _tool.Name,
        Description = _tool.Description,
        Parameters = (JsonObject)_tool.InputSchema.DeepClone(),
    };
}
