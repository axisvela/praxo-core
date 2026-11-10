package com.axisvela.praxo;

public class PraxoException extends RuntimeException {
    public final String code;

    public PraxoException(String code, String message) {
        super(message);
        this.code = code;
    }

    public static PraxoException aborted() {
        return new PraxoException("AGENT_ABORTED", "agent: aborted");
    }

    public static PraxoException maxSteps() {
        return new PraxoException("AGENT_MAX_STEPS", "agent: max steps exceeded");
    }

    public static PraxoException maxTokens() {
        return new PraxoException("AGENT_MAX_TOKENS", "agent: max tokens exceeded");
    }

    public static PraxoException contextBudget() {
        return new PraxoException("AGENT_CONTEXT_BUDGET", "agent: context budget exceeded");
    }

    public static PraxoException modelCallLimit() {
        return new PraxoException("AGENT_MODEL_CALL_LIMIT", "agent: model call limit exceeded");
    }

    public static PraxoException toolCallLimit() {
        return new PraxoException("AGENT_TOOL_CALL_LIMIT", "agent: tool call limit exceeded");
    }

    public static PraxoException toolNotSelected() {
        return new PraxoException("AGENT_TOOL_NOT_SELECTED", "agent: tool not selected");
    }

    public static PraxoException approvalDenied(String message) {
        return new PraxoException("AGENT_APPROVAL_DENIED", message);
    }

    public static PraxoException interruptUnhandled() {
        return new PraxoException(
                "AGENT_INTERRUPT_UNHANDLED",
                "agent: approval handler not configured");
    }

    public static PraxoException interruptDecisionInvalid(String message) {
        return new PraxoException("AGENT_INTERRUPT_DECISION_INVALID", message);
    }

    public static PraxoException structuredOutput(String message) {
        return new PraxoException("AGENT_STRUCTURED_OUTPUT", message);
    }

    public static PraxoException typeNotAllowed(String message) {
        return new PraxoException("CHECKPOINT_TYPE_NOT_ALLOWED", message);
    }

    public static PraxoException checkpoint(String message) {
        return new PraxoException("CHECKPOINT_ERROR", message);
    }

    public static PraxoException plugin(String message) {
        return new PraxoException("PLUGIN_INVALID_MANIFEST", message);
    }

    public static PraxoException policy(String message) {
        return new PraxoException("POLICY_ERROR", message);
    }

    public static PraxoException toolNotFound(String message) {
        return new PraxoException("TOOL_NOT_FOUND", message);
    }

    public static PraxoException mcpProtocol(String message) {
        return new PraxoException("MCP_PROTOCOL", message);
    }

    public static PraxoException mcpTransport(String message) {
        return new PraxoException("MCP_TRANSPORT", message);
    }

    public static PraxoException mcpHandshake(String message) {
        return new PraxoException("MCP_HANDSHAKE", message);
    }

    public static PraxoException mcpPagination(String message) {
        return new PraxoException("MCP_PAGINATION", message);
    }

    public static PraxoException mcpDuplicateTool(String message) {
        return new PraxoException("MCP_DUPLICATE_TOOL", message);
    }

    public static PraxoException mcpToolError(String message) {
        return new PraxoException("MCP_TOOL_ERROR", message);
    }

    public static PraxoException mcpRpc(String message) {
        return new PraxoException("MCP_RPC", message);
    }

    public static PraxoException mcpTimeout(String message) {
        return new PraxoException("MCP_TIMEOUT", message);
    }

    public static PraxoException mcpClosed(String message) {
        return new PraxoException("MCP_CLOSED", message);
    }

    public static PraxoException mcpCancelled(String message) {
        return new PraxoException("MCP_CANCELLED", message);
    }
}
