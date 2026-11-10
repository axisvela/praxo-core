use std::fmt;

#[derive(Debug, Clone)]
pub struct PraxoError {
    pub code: &'static str,
    pub message: String,
}

impl PraxoError {
    pub fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }

    pub fn aborted() -> Self {
        Self::new("AGENT_ABORTED", "agent: aborted")
    }

    pub fn max_steps() -> Self {
        Self::new("AGENT_MAX_STEPS", "agent: max steps exceeded")
    }

    pub fn max_tokens() -> Self {
        Self::new("AGENT_MAX_TOKENS", "agent: max tokens exceeded")
    }

    pub fn context_budget() -> Self {
        Self::new("AGENT_CONTEXT_BUDGET", "agent: context budget exceeded")
    }

    pub fn model_call_limit() -> Self {
        Self::new("AGENT_MODEL_CALL_LIMIT", "agent: model call limit exceeded")
    }

    pub fn tool_call_limit() -> Self {
        Self::new("AGENT_TOOL_CALL_LIMIT", "agent: tool call limit exceeded")
    }

    pub fn tool_not_selected() -> Self {
        Self::new("AGENT_TOOL_NOT_SELECTED", "agent: tool not selected")
    }

    pub fn approval_denied(message: impl Into<String>) -> Self {
        Self::new("AGENT_APPROVAL_DENIED", message)
    }

    pub fn interrupt_unhandled() -> Self {
        Self::new(
            "AGENT_INTERRUPT_UNHANDLED",
            "agent: approval handler not configured",
        )
    }

    pub fn interrupt_decision_invalid(message: impl Into<String>) -> Self {
        Self::new("AGENT_INTERRUPT_DECISION_INVALID", message)
    }

    pub fn structured_output(message: impl Into<String>) -> Self {
        Self::new("AGENT_STRUCTURED_OUTPUT", message)
    }

    pub fn type_not_allowed(message: impl Into<String>) -> Self {
        Self::new("CHECKPOINT_TYPE_NOT_ALLOWED", message)
    }

    pub fn checkpoint(message: impl Into<String>) -> Self {
        Self::new("CHECKPOINT_ERROR", message)
    }

    pub fn plugin(message: impl Into<String>) -> Self {
        Self::new("PLUGIN_INVALID_MANIFEST", message)
    }

    pub fn policy(message: impl Into<String>) -> Self {
        Self::new("POLICY_ERROR", message)
    }

    pub fn tool_not_found(message: impl Into<String>) -> Self {
        Self::new("TOOL_NOT_FOUND", message)
    }

    pub fn mcp_protocol(message: impl Into<String>) -> Self {
        Self::new("MCP_PROTOCOL", message)
    }

    pub fn mcp_transport(message: impl Into<String>) -> Self {
        Self::new("MCP_TRANSPORT", message)
    }

    pub fn mcp_handshake(message: impl Into<String>) -> Self {
        Self::new("MCP_HANDSHAKE", message)
    }

    pub fn mcp_pagination(message: impl Into<String>) -> Self {
        Self::new("MCP_PAGINATION", message)
    }

    pub fn mcp_duplicate_tool(message: impl Into<String>) -> Self {
        Self::new("MCP_DUPLICATE_TOOL", message)
    }

    pub fn mcp_tool_error(message: impl Into<String>) -> Self {
        Self::new("MCP_TOOL_ERROR", message)
    }

    pub fn mcp_rpc(message: impl Into<String>) -> Self {
        Self::new("MCP_RPC", message)
    }

    pub fn mcp_timeout(message: impl Into<String>) -> Self {
        Self::new("MCP_TIMEOUT", message)
    }

    pub fn mcp_closed(message: impl Into<String>) -> Self {
        Self::new("MCP_CLOSED", message)
    }

    pub fn mcp_cancelled(message: impl Into<String>) -> Self {
        Self::new("MCP_CANCELLED", message)
    }
}

impl fmt::Display for PraxoError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for PraxoError {}

pub type Result<T> = std::result::Result<T, PraxoError>;
