using System.Diagnostics;
using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public interface IMcpTransport : IDisposable
{
    int? ProcessId { get; }

    bool HasExited { get; }

    void Start();

    void Send(JsonObject message);

    void Notify(string method, JsonObject? parameters);

    JsonObject Request(
        string method,
        JsonObject? parameters,
        TimeSpan timeout,
        CancellationToken cancellationToken);

    void Close();
}

public sealed class McpServerOptions
{
    public string Command { get; set; } = "";

    public List<string> Args { get; set; } = new();

    public Dictionary<string, string>? Env { get; set; }

    public string? WorkingDirectory { get; set; }

    public TimeSpan CloseTimeout { get; set; } = TimeSpan.FromSeconds(5);
}

public sealed class McpStdioTransport : IMcpTransport
{
    private readonly McpServerOptions _options;
    private readonly object _pendingLock = new();
    private readonly object _writeLock = new();
    private readonly Dictionary<long, TaskCompletionSource<JsonObject>> _pending = new();
    private Process? _process;
    private Thread? _reader;
    private long _nextId;
    private volatile bool _closed;
    private Exception? _readError;

    public McpStdioTransport(McpServerOptions options)
    {
        _options = options;
    }

    public int? ProcessId
    {
        get
        {
            try
            {
                return _process?.Id;
            }
            catch (InvalidOperationException)
            {
                return null;
            }
        }
    }

    public bool HasExited
    {
        get
        {
            try
            {
                return _process == null || _process.HasExited;
            }
            catch (InvalidOperationException)
            {
                return true;
            }
        }
    }

    public void Start()
    {
        if (_process != null)
        {
            return;
        }
        if (string.IsNullOrWhiteSpace(_options.Command))
        {
            throw PraxoException.McpTransport("mcp: command is required");
        }
        var startInfo = BuildStartInfo();
        try
        {
            _process = Process.Start(startInfo)
                ?? throw PraxoException.McpTransport("mcp: failed to start server");
        }
        catch (Exception error) when (error is not PraxoException)
        {
            throw PraxoException.McpTransport($"mcp: failed to start server: {error.Message}");
        }
        _reader = new Thread(ReadLoop)
        {
            IsBackground = true,
            Name = "praxo-mcp-reader",
        };
        _reader.Start();
    }

    public void Send(JsonObject message)
    {
        if (_closed)
        {
            throw PraxoException.McpClosed("mcp: client is closed");
        }
        var process = _process
            ?? throw PraxoException.McpTransport("mcp: transport is not started");
        lock (_writeLock)
        {
            try
            {
                process.StandardInput.Write(Json.Stringify(message) + "\n");
                process.StandardInput.Flush();
            }
            catch (Exception error) when (error is IOException or ObjectDisposedException or InvalidOperationException)
            {
                throw PraxoException.McpTransport($"mcp: failed to write to server: {error.Message}");
            }
        }
    }

    public void Notify(string method, JsonObject? parameters)
    {
        var message = new JsonObject
        {
            ["jsonrpc"] = "2.0",
            ["method"] = method,
        };
        if (parameters != null)
        {
            message["params"] = parameters.DeepClone();
        }
        Send(message);
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
        if (_readError != null)
        {
            throw PraxoException.McpClosed($"mcp: connection closed: {_readError.Message}");
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
        var pending = new TaskCompletionSource<JsonObject>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        lock (_pendingLock)
        {
            _pending[id] = pending;
        }
        try
        {
            Send(message);
            if (timeout <= TimeSpan.Zero)
            {
                return pending.Task.GetAwaiter().GetResult();
            }
            return pending.Task.WaitAsync(timeout, cancellationToken).GetAwaiter().GetResult();
        }
        catch (TimeoutException)
        {
            RemovePending(id);
            TryNotifyCancelled(id, "timeout");
            throw PraxoException.McpTimeout($"mcp: {method} timed out after {timeout.TotalMilliseconds}ms");
        }
        catch (OperationCanceledException)
        {
            RemovePending(id);
            TryNotifyCancelled(id, "cancelled");
            throw;
        }
        catch
        {
            RemovePending(id);
            throw;
        }
    }

    public void Close()
    {
        if (_closed)
        {
            return;
        }
        _closed = true;
        FailPending(PraxoException.McpClosed("mcp: client closed"));
        var process = _process;
        if (process != null)
        {
            try
            {
                process.StandardInput.Close();
            }
            catch (Exception error) when (error is IOException or ObjectDisposedException or InvalidOperationException)
            {
            }
            try
            {
                if (!process.WaitForExit((int)_options.CloseTimeout.TotalMilliseconds))
                {
                    process.Kill(entireProcessTree: true);
                    process.WaitForExit((int)_options.CloseTimeout.TotalMilliseconds);
                }
            }
            catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception or NotSupportedException)
            {
            }
            process.Dispose();
            _process = null;
        }
        _reader?.Join(TimeSpan.FromSeconds(2));
    }

    public void Dispose() => Close();

    private ProcessStartInfo BuildStartInfo()
    {
        var info = new ProcessStartInfo
        {
            UseShellExecute = false,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = false,
            CreateNoWindow = true,
            StandardOutputEncoding = new UTF8Encoding(false),
            StandardInputEncoding = new UTF8Encoding(false),
        };
        if (!string.IsNullOrEmpty(_options.WorkingDirectory))
        {
            info.WorkingDirectory = _options.WorkingDirectory;
        }
        if (OperatingSystem.IsWindows() && IsBatch(_options.Command))
        {
            info.FileName = Environment.GetEnvironmentVariable("ComSpec") ?? "cmd.exe";
            info.Arguments = "/d /s /c \"" + Quote(_options.Command) + " "
                + string.Join(" ", _options.Args.Select(Quote)) + "\"";
        }
        else
        {
            info.FileName = _options.Command;
            foreach (var argument in _options.Args)
            {
                info.ArgumentList.Add(argument);
            }
        }
        if (_options.Env != null)
        {
            foreach (var item in _options.Env)
            {
                info.Environment[item.Key] = item.Value;
            }
        }
        return info;
    }

    private static bool IsBatch(string command)
    {
        var extension = Path.GetExtension(command);
        return extension.Equals(".bat", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".cmd", StringComparison.OrdinalIgnoreCase);
    }

    private static string Quote(string value)
        => "\"" + value.Replace("\"", "\\\"") + "\"";

    private void ReadLoop()
    {
        var process = _process;
        if (process == null)
        {
            return;
        }
        try
        {
            while (true)
            {
                var line = process.StandardOutput.ReadLine();
                if (line == null)
                {
                    break;
                }
                if (string.IsNullOrWhiteSpace(line))
                {
                    continue;
                }
                JsonObject message;
                try
                {
                    if (!Json.TryParseObject(line, out message))
                    {
                        throw PraxoException.McpProtocol("mcp: server sent invalid JSON");
                    }
                }
                catch (Exception error) when (error is not PraxoException)
                {
                    throw PraxoException.McpProtocol($"mcp: server sent invalid JSON: {error.Message}");
                }
                if (!TryGetId(message, out var id))
                {
                    continue;
                }
                TaskCompletionSource<JsonObject>? pending;
                lock (_pendingLock)
                {
                    if (!_pending.Remove(id, out pending))
                    {
                        continue;
                    }
                }
                pending.TrySetResult(message);
            }
            FailPending(PraxoException.McpClosed("mcp: connection closed"));
        }
        catch (Exception error)
        {
            _readError = error;
            FailPending(error is PraxoException praxo
                ? praxo
                : PraxoException.McpProtocol($"mcp: read failed: {error.Message}"));
        }
    }

    private static bool TryGetId(JsonObject message, out long id)
    {
        id = 0;
        var node = message["id"];
        if (node is not JsonValue value)
        {
            return false;
        }
        if (value.TryGetValue<long>(out id))
        {
            return true;
        }
        if (value.TryGetValue<int>(out var small))
        {
            id = small;
            return true;
        }
        if (value.TryGetValue<string>(out var text))
        {
            return long.TryParse(text, out id);
        }
        return false;
    }

    private void RemovePending(long id)
    {
        lock (_pendingLock)
        {
            _pending.Remove(id);
        }
    }

    private void TryNotifyCancelled(long id, string reason)
    {
        try
        {
            if (_closed)
            {
                return;
            }
            Notify("notifications/cancelled", new JsonObject
            {
                ["requestId"] = id,
                ["reason"] = reason,
            });
        }
        catch (Exception)
        {
        }
    }

    private void FailPending(Exception error)
    {
        List<TaskCompletionSource<JsonObject>> pending;
        lock (_pendingLock)
        {
            pending = _pending.Values.ToList();
            _pending.Clear();
        }
        foreach (var item in pending)
        {
            item.TrySetException(error);
        }
    }
}
