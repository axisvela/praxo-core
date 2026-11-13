namespace Praxo.Core.Delegation;

public enum SubagentMode
{
    Isolated,
    Fork,
}

public enum SubagentStatus
{
    Queued,
    Running,
    Completed,
    Failed,
    Canceled,
}

public static class SubagentValues
{
    public static string Wire(this SubagentMode mode)
        => mode == SubagentMode.Fork ? "fork" : "isolated";

    public static string Wire(this SubagentStatus status) => status switch
    {
        SubagentStatus.Queued => "queued",
        SubagentStatus.Running => "running",
        SubagentStatus.Completed => "completed",
        SubagentStatus.Failed => "failed",
        _ => "canceled",
    };

    public static bool Terminal(this SubagentStatus status)
        => status is SubagentStatus.Completed
            or SubagentStatus.Failed
            or SubagentStatus.Canceled;
}

public sealed class SubagentRequest
{
    public string ParentSessionId { get; set; } = "";

    public string AgentId { get; set; } = "";

    public string Prompt { get; set; } = "";

    public Dictionary<string, object?> Context { get; set; } = new();

    public SubagentMode Mode { get; set; } = SubagentMode.Isolated;

    public List<Message> History { get; set; } = new();
}

public sealed class SubagentResult
{
    public string TaskId { get; set; } = "";

    public string AgentId { get; set; } = "";

    public string Output { get; set; } = "";

    public Usage? Usage { get; set; }
}

public sealed class SubagentTask
{
    public string Id { get; init; } = "";

    public string ParentSessionId { get; init; } = "";

    public string AgentId { get; init; } = "";

    public SubagentMode Mode { get; init; }

    public SubagentStatus Status { get; set; }

    public string Output { get; set; } = "";

    public string Error { get; set; } = "";

    public DateTimeOffset CreatedAt { get; init; }

    public DateTimeOffset UpdatedAt { get; set; }
}
