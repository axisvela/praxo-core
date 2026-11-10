namespace Praxo.Core;

public sealed class PraxoException : Exception
{
    public string Code { get; }

    public PraxoException(string code, string message) : base(message)
    {
        Code = code;
    }

    public static PraxoException ModelCallLimit()
        => new("AGENT_MODEL_CALL_LIMIT", "agent: model call limit exceeded");

    public static PraxoException ToolCallLimit()
        => new("AGENT_TOOL_CALL_LIMIT", "agent: tool call limit exceeded");

    public static PraxoException MaxSteps()
        => new("AGENT_MAX_STEPS", "agent: maximum steps exceeded");

    public static PraxoException MaxTokens()
        => new("AGENT_MAX_TOKENS", "agent: token budget exceeded");

    public static PraxoException ContextBudget()
        => new("AGENT_CONTEXT_BUDGET", "agent: context budget cannot fit");

    public static PraxoException StructuredOutput(string message)
        => new("AGENT_STRUCTURED_OUTPUT", message);

    public static PraxoException ToolNotSelected()
        => new("AGENT_TOOL_NOT_SELECTED", "agent: tool is not selected");

    public static PraxoException ApprovalDenied(string message)
        => new("AGENT_APPROVAL_DENIED", message);

    public static PraxoException InterruptUnhandled()
        => new("AGENT_INTERRUPT_UNHANDLED", "agent: approval handler not configured");

    public static PraxoException InterruptDecisionInvalid(string message)
        => new("AGENT_INTERRUPT_DECISION_INVALID", message);

    public static PraxoException ToolNotFound(string message)
        => new("TOOL_NOT_FOUND", message);

    public static PraxoException TypeNotAllowed(string message)
        => new("CHECKPOINT_TYPE_NOT_ALLOWED", message);

    public static PraxoException Checkpoint(string message)
        => new("CHECKPOINT_ERROR", message);

    public static PraxoException Plugin(string message)
        => new("PLUGIN_INVALID_MANIFEST", message);

    public static PraxoException Policy(string message)
        => new("POLICY_ERROR", message);

    public static PraxoException McpProtocol(string message)
        => new("MCP_PROTOCOL", message);

    public static PraxoException McpTransport(string message)
        => new("MCP_TRANSPORT", message);

    public static PraxoException McpHandshake(string message)
        => new("MCP_HANDSHAKE", message);

    public static PraxoException McpPagination(string message)
        => new("MCP_PAGINATION", message);

    public static PraxoException McpDuplicateTool(string message)
        => new("MCP_DUPLICATE_TOOL", message);

    public static PraxoException McpToolError(string message)
        => new("MCP_TOOL_ERROR", message);

    public static PraxoException McpRpc(string message)
        => new("MCP_RPC", message);

    public static PraxoException McpTimeout(string message)
        => new("MCP_TIMEOUT", message);

    public static PraxoException McpClosed(string message)
        => new("MCP_CLOSED", message);

    public static PraxoException McpCancelled(string message)
        => new("MCP_CANCELLED", message);
}
