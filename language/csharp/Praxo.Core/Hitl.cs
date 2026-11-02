using System.Text.Json.Nodes;

namespace Praxo.Core;

public sealed class Interrupt
{
    public string RunId { get; set; } = "";

    public string SessionId { get; set; } = "";

    public ToolCall Call { get; set; } = new();
}

public static class InterruptAction
{
    public const string Approve = "approve";
    public const string Edit = "edit";
    public const string Reject = "reject";
    public const string Respond = "respond";
}

public sealed class InterruptDecision
{
    public string Action { get; set; } = "";

    public JsonObject? Arguments { get; set; }

    public string Response { get; set; } = "";

    public string Reason { get; set; } = "";
}

public interface IInterruptHandler
{
    InterruptDecision Decide(Interrupt interrupt);
}

public interface IInterruptApproval
{
    bool Approve(Interrupt interrupt);
}
