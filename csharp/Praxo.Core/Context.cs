using System.Text;
using System.Text.Json.Nodes;

namespace Praxo.Core;

public static class ContextEstimator
{
    public const string CompactMarkerPrefix = "[context compacted:";

    public static int EstimateTokens(IReadOnlyList<Message> messages)
    {
        var total = 0;
        foreach (var message in messages)
        {
            total += 4
                + Bytes(message.Content) / 4
                + Bytes(message.ToolId) / 4;
            foreach (var block in message.ContentBlocks)
            {
                total += 4
                    + Bytes(block.Text) / 4
                    + Bytes(block.ImageUrl) / 4
                    + Bytes(block.Data) / 4;
            }
            foreach (var call in message.ToolCalls)
            {
                total += 4 + Bytes(call.Name) / 4;
                total += Bytes(Json.Stringify(call.Arguments)) / 4;
            }
        }
        return total;
    }

    public static string TruncateToTokens(string value, int tokens)
    {
        if (tokens <= 0)
        {
            return "";
        }
        var limit = tokens * 4;
        var bytes = Encoding.UTF8.GetBytes(value);
        if (bytes.Length <= limit)
        {
            return value;
        }
        if (limit <= 16)
        {
            return Encoding.UTF8.GetString(bytes, 0, limit);
        }
        return Encoding.UTF8.GetString(bytes, 0, limit - 16) + "\n[truncated]";
    }

    private static int Bytes(string? value)
        => value == null ? 0 : Encoding.UTF8.GetByteCount(value);
}

public sealed class ContextBudget
{
    public int MaxTokens { get; }

    public int KeepRecent { get; }

    public ContextBudget(int maxTokens, int keepRecent)
    {
        MaxTokens = maxTokens;
        KeepRecent = keepRecent;
    }

    public (List<Message> Messages, bool Ok) Compact(IReadOnlyList<Message> messages)
    {
        if (MaxTokens == 0 || ContextEstimator.EstimateTokens(messages) <= MaxTokens)
        {
            return (messages.ToList(), true);
        }
        var system = new List<Message>();
        var rest = new List<Message>();
        foreach (var message in messages)
        {
            if (message.Role == Roles.System)
            {
                if ((message.Content ?? "").StartsWith(ContextEstimator.CompactMarkerPrefix, StringComparison.Ordinal))
                {
                    continue;
                }
                system.Add(message);
            }
            else
            {
                rest.Add(message);
            }
        }
        if (ContextEstimator.EstimateTokens(system) > MaxTokens)
        {
            if (system.Count == 0)
            {
                return (new List<Message>(), false);
            }
            var truncated = Clone(system[0]);
            truncated.Content = ContextEstimator.TruncateToTokens(
                truncated.Content ?? "", Math.Max(0, MaxTokens - 4));
            system = new List<Message> { truncated };
            if (ContextEstimator.EstimateTokens(system) > MaxTokens)
            {
                return (new List<Message>(), false);
            }
        }
        var keep = KeepRecent > 0 ? KeepRecent : 4;
        var start = Math.Max(0, rest.Count - keep);
        while (start > 0 && rest[start].Role == Roles.Tool)
        {
            start--;
        }
        var marker = Message.Text(
            Roles.System,
            $"{ContextEstimator.CompactMarkerPrefix} {start} older messages omitted]");
        var kept = rest.Skip(start).Select(Clone).ToList();
        var output = Build(system, marker, start > 0, kept);
        while (ContextEstimator.EstimateTokens(output) > MaxTokens && kept.Count > 1)
        {
            if (kept[1].Role == Roles.Tool)
            {
                break;
            }
            kept.RemoveAt(0);
            output = Build(system, marker, start > 0, kept);
        }
        return ContextEstimator.EstimateTokens(output) > MaxTokens
            ? (new List<Message>(), false)
            : (output, true);
    }

    private static List<Message> Build(
        IReadOnlyList<Message> system, Message marker, bool includeMarker, IReadOnlyList<Message> kept)
    {
        var output = system.Select(Clone).ToList();
        if (includeMarker)
        {
            output.Add(Clone(marker));
        }
        output.AddRange(kept.Select(Clone));
        return output;
    }

    private static Message Clone(Message message)
        => new()
        {
            Role = message.Role,
            Content = message.Content,
            ContentBlocks = message.ContentBlocks.Select(block => new ContentBlock
            {
                Type = block.Type,
                Text = block.Text,
                ImageUrl = block.ImageUrl,
                Data = block.Data,
            }).ToList(),
            ToolCalls = message.ToolCalls.Select(call => new ToolCall
            {
                Id = call.Id,
                Name = call.Name,
                Arguments = (JsonObject)call.Arguments.DeepClone(),
            }).ToList(),
            ToolId = message.ToolId,
        };
}

public interface IContextCompactor
{
    List<Message> Compact(IReadOnlyList<Message> messages, ContextBudget budget);
}

public sealed class ModelSummarizer : IContextCompactor
{
    public const string SummaryMarkerPrefix = "[context summary:";

    public const string DefaultSummaryPrompt =
        "Summarize the conversation so far. Preserve decisions, open tasks, tool results, constraints, and user preferences. Be concise.";

    private readonly IModel? _model;
    private readonly string _prompt;
    private readonly int _maxSummaryTokens;

    public ModelSummarizer(IModel? model = null, string prompt = "", int maxSummaryTokens = 0)
    {
        _model = model;
        _prompt = prompt;
        _maxSummaryTokens = maxSummaryTokens;
    }

    public List<Message> Compact(IReadOnlyList<Message> messages, ContextBudget budget)
    {
        if (budget.MaxTokens == 0 || ContextEstimator.EstimateTokens(messages) <= budget.MaxTokens)
        {
            return messages.ToList();
        }
        if (_model == null)
        {
            return Fit(messages, budget);
        }
        var system = new List<Message>();
        var rest = new List<Message>();
        foreach (var message in messages)
        {
            if (message.Role == Roles.System)
            {
                var content = message.Content ?? "";
                if (content.StartsWith(ContextEstimator.CompactMarkerPrefix, StringComparison.Ordinal)
                    || content.StartsWith(SummaryMarkerPrefix, StringComparison.Ordinal))
                {
                    continue;
                }
                system.Add(message);
            }
            else
            {
                rest.Add(message);
            }
        }
        var keep = budget.KeepRecent > 0 ? budget.KeepRecent : 4;
        var start = Math.Max(0, rest.Count - keep);
        while (start > 0 && rest[start].Role == Roles.Tool)
        {
            start--;
        }
        if (start == 0)
        {
            return Fit(messages, budget);
        }
        var prompt = string.IsNullOrWhiteSpace(_prompt) ? DefaultSummaryPrompt : _prompt;
        var requestMessages = new List<Message> { Message.Text(Roles.System, prompt) };
        requestMessages.AddRange(rest.Take(start));
        string summary;
        try
        {
            summary = _model.Generate(Request.Of(requestMessages)).Message.Content ?? "";
        }
        catch (PraxoException)
        {
            return Fit(messages, budget);
        }
        if (string.IsNullOrWhiteSpace(summary))
        {
            return Fit(messages, budget);
        }
        var maxSummary = _maxSummaryTokens > 0 ? _maxSummaryTokens : budget.MaxTokens / 4;
        var trimmed = ContextEstimator.TruncateToTokens(summary.Trim(), maxSummary);
        var output = system.ToList();
        output.Add(Message.Text(Roles.System, $"{SummaryMarkerPrefix} {trimmed}]"));
        output.AddRange(rest.Skip(start));
        return Fit(output, budget);
    }

    private static List<Message> Fit(IReadOnlyList<Message> messages, ContextBudget budget)
    {
        var (output, ok) = budget.Compact(messages);
        if (!ok)
        {
            throw PraxoException.ContextBudget();
        }
        return output;
    }
}
