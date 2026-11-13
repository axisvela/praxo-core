using System.Text.Json.Nodes;
using Praxo.Core;

namespace Praxo.CheckpointExample;

public static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--test")
        {
            RunDeterministicTest();
            Console.WriteLine("checkpoint test: ok");
            return 0;
        }

        Console.WriteLine("Run with --test; wire a durable store in Program.cs.");
        return 0;
    }

    private static void RunDeterministicTest()
    {
        var allowlist = DefaultAllowlist();
        var store = new MemoryStore();
        SaveCheckpoint(store, allowlist, "session-1", 1, new[] { "book" });
        SaveCheckpoint(store, allowlist, "session-1", 2, new[] { "book", "pen" });

        var loaded = store.Load("session-1")
            ?? throw new InvalidOperationException("checkpoint not found");
        if (loaded.Version != 2)
        {
            throw new InvalidOperationException(
                $"unexpected checkpoint version: {loaded.Version}");
        }
        var payload = allowlist.Unmarshal(loaded.Payload) as JsonObject
            ?? throw new InvalidOperationException("payload is not an object");
        if (payload["session_id"]?.GetValue<string>() != "session-1")
        {
            throw new InvalidOperationException("session id did not round trip");
        }
        if (payload["items"] is not JsonArray items || items.Count != 2)
        {
            throw new InvalidOperationException("items did not round trip");
        }

        try
        {
            allowlist.Marshal("unknown", new JsonObject());
        }
        catch (PraxoException error)
            when (error.Code == "CHECKPOINT_TYPE_NOT_ALLOWED")
        {
            return;
        }
        throw new InvalidOperationException("unregistered payload type was accepted");
    }

    private static CheckpointAllowlist DefaultAllowlist()
    {
        var allowlist = new CheckpointAllowlist();
        allowlist.Register("order");
        return allowlist;
    }

    private static void SaveCheckpoint(
        MemoryStore store,
        CheckpointAllowlist allowlist,
        string sessionId,
        int version,
        IReadOnlyList<string> items)
    {
        var payload = allowlist.Marshal("order", new JsonObject
        {
            ["session_id"] = sessionId,
            ["items"] = new JsonArray(items
                .Select(item => JsonValue.Create(item))
                .ToArray()),
        });
        store.Save(new CheckpointRecord($"cp-{version}", sessionId, version, payload));
    }

    private sealed record CheckpointRecord(
        string Id,
        string SessionId,
        int Version,
        string Payload);

    private sealed class MemoryStore
    {
        private readonly Dictionary<string, CheckpointRecord> _records = new();

        public void Save(CheckpointRecord record)
        {
            _records[record.SessionId] = record;
        }

        public CheckpointRecord? Load(string sessionId)
            => _records.GetValueOrDefault(sessionId);
    }
}
