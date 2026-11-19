using System.Diagnostics;
using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class PluginProcessConfig
{
    public string PluginId { get; set; } = "";

    public string Path { get; set; } = "";

    public List<string> Args { get; set; } = new();

    public string? Dir { get; set; }

    public Dictionary<string, string>? Env { get; set; }

    public string Token { get; set; } = "";

    public string TokenEnvVar { get; set; } = "PRAXOVELA_PLUGIN_TOKEN";

    public TimeSpan StartTimeout { get; set; } = TimeSpan.FromSeconds(10);

    public TimeSpan InvokeTimeout { get; set; } = TimeSpan.FromSeconds(30);

    public TimeSpan GracePeriod { get; set; } = TimeSpan.FromSeconds(5);

    public int MaxFrameBytes { get; set; } = 8 << 20;
}

public sealed class PluginProcessException : Exception
{
    private static readonly HashSet<string> Codes = new()
    {
        "CAPABILITY_DENIED", "NOT_ACTIVE", "NOT_FOUND", "INVALID_REQUEST",
        "TIMEOUT", "INTERNAL", "CANCELED",
    };

    public string Code { get; }

    public PluginProcessException(string code, string message)
        : base(string.IsNullOrEmpty(message) ? code : message)
    {
        Code = Codes.Contains(code) ? code : "INTERNAL";
    }
}

public sealed class PluginProcessHost : IDisposable
{
    public const int ProtocolVersion = 1;
    public const string ControlService = "host.control";
    public const string HealthMethod = "health";
    public const string ShutdownMethod = "shutdown";
    public const string CancelMethod = "cancel";

    private readonly PluginProcessConfig _config;
    private readonly string _token;
    private Process? _process;
    private long _sequence;
    private bool _active;

    public PluginProcessHost(PluginProcessConfig config)
    {
        if (string.IsNullOrEmpty(config.PluginId))
        {
            throw new ArgumentException("plugin: PluginID is required");
        }
        if (string.IsNullOrEmpty(config.Path))
        {
            throw new ArgumentException("plugin: path is required");
        }
        _config = config;
        _token = string.IsNullOrEmpty(config.Token)
            ? Convert.ToHexString(Guid.NewGuid().ToByteArray()).ToLowerInvariant()
            : config.Token;
    }

    public string PluginId => _config.PluginId;

    public bool IsActive => _active;

    public string StderrText { get; private set; } = "";

    public void Start()
    {
        if (_process != null)
        {
            throw new InvalidOperationException("plugin: host already started");
        }
        var info = new ProcessStartInfo
        {
            FileName = _config.Path,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        foreach (var argument in _config.Args)
        {
            info.ArgumentList.Add(argument);
        }
        if (!string.IsNullOrEmpty(_config.Dir))
        {
            info.WorkingDirectory = _config.Dir;
        }
        if (_config.Env != null)
        {
            info.Environment.Clear();
            foreach (var (key, value) in _config.Env)
            {
                info.Environment[key] = value;
            }
        }
        info.Environment[_config.TokenEnvVar] = _token;
        _process = new Process { StartInfo = info };
        _process.Start();
        _ = ReadStderrAsync(_process);
        try
        {
            CallAsync(ControlService, HealthMethod, Array.Empty<byte>(),
                _config.StartTimeout).GetAwaiter().GetResult();
        }
        catch
        {
            Terminate();
            throw;
        }
        _active = true;
    }

    public byte[] Invoke(string service, string method, byte[]? payload = null)
    {
        return Invoke(service, method, payload, _config.InvokeTimeout);
    }

    public byte[] Invoke(
        string service, string method, byte[]? payload, TimeSpan timeout)
    {
        if (!_active)
        {
            throw new PluginProcessException("NOT_ACTIVE", "plugin: host is not active");
        }
        return CallAsync(service, method, payload ?? Array.Empty<byte>(), timeout)
            .GetAwaiter().GetResult();
    }

    public void Stop()
    {
        if (_process == null)
        {
            return;
        }
        try
        {
            if (_active)
            {
                CallAsync(ControlService, ShutdownMethod, Array.Empty<byte>(),
                    _config.GracePeriod).GetAwaiter().GetResult();
            }
        }
        catch
        {
            // best effort
        }
        _active = false;
        Terminate();
    }

    private async Task<byte[]> CallAsync(
        string service, string method, byte[] payload, TimeSpan timeout)
    {
        var process = _process
            ?? throw new PluginProcessException("INTERNAL", "plugin: process is closed");
        var id = $"req-{Interlocked.Increment(ref _sequence)}";
        var frame = new JsonObject
        {
            ["id"] = id,
            ["version"] = ProtocolVersion,
            ["plugin_id"] = _config.PluginId,
            ["service"] = service,
            ["method"] = method,
            ["token"] = _token,
            ["payload"] = Convert.ToBase64String(payload),
        };
        var encoded = frame.ToJsonString() + "\n";
        if (Encoding.UTF8.GetByteCount(encoded) > _config.MaxFrameBytes)
        {
            throw new PluginProcessException(
                "INVALID_REQUEST", "plugin: request frame too large");
        }
        await process.StandardInput.WriteAsync(encoded);
        await process.StandardInput.FlushAsync();
        using var cancellation = new CancellationTokenSource(timeout);
        while (true)
        {
            string? line;
            try
            {
                line = await process.StandardOutput.ReadLineAsync(cancellation.Token);
            }
            catch (OperationCanceledException)
            {
                SendCancel(id);
                Terminate();
                throw new PluginProcessException(
                    "TIMEOUT", "plugin: invocation timed out");
            }
            if (line == null)
            {
                var detail = StderrText;
                Terminate();
                throw new PluginProcessException(
                    "INTERNAL", detail.Length == 0 ? "plugin: process exited" : detail);
            }
            JsonObject? response;
            try
            {
                response = JsonNode.Parse(line) as JsonObject;
            }
            catch (System.Text.Json.JsonException)
            {
                continue;
            }
            if (response == null ||
                response["id"]?.GetValue<string>() != id)
            {
                continue;
            }
            if (response["ok"]?.GetValue<bool>() != true)
            {
                var code = response["code"]?.GetValue<string>() ?? "INTERNAL";
                var message = response["message"]?.GetValue<string>() ?? "";
                throw new PluginProcessException(code, message);
            }
            var payloadText = response["payload"]?.GetValue<string>() ?? "";
            try
            {
                return Convert.FromBase64String(payloadText);
            }
            catch (FormatException)
            {
                throw new PluginProcessException("INTERNAL", "plugin: invalid payload");
            }
        }
    }

    private void SendCancel(string id)
    {
        var process = _process;
        if (process == null)
        {
            return;
        }
        var frame = new JsonObject
        {
            ["id"] = id,
            ["version"] = ProtocolVersion,
            ["plugin_id"] = _config.PluginId,
            ["service"] = ControlService,
            ["method"] = CancelMethod,
            ["token"] = _token,
        };
        try
        {
            process.StandardInput.Write(frame.ToJsonString() + "\n");
            process.StandardInput.Flush();
        }
        catch
        {
            // best effort
        }
    }

    private async Task ReadStderrAsync(Process process)
    {
        var builder = new StringBuilder();
        var buffer = new char[4096];
        try
        {
            int count;
            while ((count = await process.StandardError.ReadAsync(buffer, 0, buffer.Length)) > 0)
            {
                if (builder.Length < 16 << 10)
                {
                    var remaining = (16 << 10) - builder.Length;
                    builder.Append(buffer, 0, Math.Min(count, remaining));
                }
            }
        }
        catch
        {
            // stream closed
        }
        StderrText = builder.ToString();
    }

    private void Terminate()
    {
        _active = false;
        var process = _process;
        if (process != null)
        {
            try
            {
                if (!process.HasExited)
                {
                    process.Kill(entireProcessTree: true);
                    process.WaitForExit(1000);
                }
            }
            catch
            {
                // best effort
            }
            process.Dispose();
        }
        _process = null;
    }

    public void Dispose() => Stop();
}
