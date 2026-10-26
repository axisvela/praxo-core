namespace Praxo.Core;

public interface IMemoryStore
{
    void Put(string sessionId, MemoryRecord record);

    IReadOnlyList<MemoryRecord> Search(string sessionId, string query, int limit);
}

public sealed class InMemoryMemoryStore : IMemoryStore
{
    private readonly object _lock = new();
    private readonly Dictionary<string, List<MemoryRecord>> _records = new();
    private long _sequence;

    public void Put(string sessionId, MemoryRecord record)
    {
        lock (_lock)
        {
            if (string.IsNullOrEmpty(record.Id))
            {
                record.Id = $"mem-{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}-{_sequence++}";
            }
            if (string.IsNullOrEmpty(record.CreatedAt))
            {
                record.CreatedAt = Clock.NowIso();
            }
            if (!_records.TryGetValue(sessionId, out var items))
            {
                items = new List<MemoryRecord>();
                _records[sessionId] = items;
            }
            items.Add(record);
        }
    }

    public IReadOnlyList<MemoryRecord> Search(string sessionId, string query, int limit)
    {
        lock (_lock)
        {
            if (!_records.TryGetValue(sessionId, out var items))
            {
                return Array.Empty<MemoryRecord>();
            }
            var needle = query.Trim().ToLowerInvariant();
            var matches = items
                .Where(item => needle.Length == 0
                    || item.Content.ToLowerInvariant().Contains(needle, StringComparison.Ordinal))
                .OrderByDescending(item => item.CreatedAt ?? "", StringComparer.Ordinal)
                .ToList();
            return limit > 0 && matches.Count > limit
                ? matches.Take(limit).ToList()
                : matches;
        }
    }
}
