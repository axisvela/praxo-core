from __future__ import annotations


class PraxoError(Exception):
    code = "PRAXO_ERROR"

    def __init__(self, message: str | None = None) -> None:
        super().__init__(message or self.code)
        self.message = message or self.code


class MaxStepsError(PraxoError):
    code = "AGENT_MAX_STEPS"


class MaxTokensError(PraxoError):
    code = "AGENT_MAX_TOKENS"


class ApprovalDeniedError(PraxoError):
    code = "AGENT_APPROVAL_DENIED"


class InterruptUnhandledError(PraxoError):
    code = "AGENT_INTERRUPT_UNHANDLED"


class ContextBudgetError(PraxoError):
    code = "AGENT_CONTEXT_BUDGET"


class SubagentUpdateUnsupportedError(PraxoError):
    code = "AGENT_SUBAGENT_UPDATE_UNSUPPORTED"


class RubricFailedError(PraxoError):
    code = "AGENT_RUBRIC_FAILED"


class InterruptDecisionInvalidError(PraxoError):
    code = "AGENT_INTERRUPT_DECISION_INVALID"


class ModelCallLimitError(PraxoError):
    code = "AGENT_MODEL_CALL_LIMIT"


class ToolCallLimitError(PraxoError):
    code = "AGENT_TOOL_CALL_LIMIT"


class StructuredOutputError(PraxoError):
    code = "AGENT_STRUCTURED_OUTPUT"


class ToolNotSelectedError(PraxoError):
    code = "AGENT_TOOL_NOT_SELECTED"


class CheckpointError(PraxoError):
    code = "CHECKPOINT_ERROR"


class TypeNotAllowedError(PraxoError):
    code = "CHECKPOINT_TYPE_NOT_ALLOWED"


class BodyTooLargeError(PraxoError):
    code = "HTTP_BODY_TOO_LARGE"


class NotActiveError(PraxoError):
    code = "PLUGIN_NOT_ACTIVE"


class InvalidTransitionError(PraxoError):
    code = "PLUGIN_INVALID_TRANSITION"


class DrainTimeoutError(PraxoError):
    code = "PLUGIN_DRAIN_TIMEOUT"


class DrainCanceledError(PraxoError):
    code = "PLUGIN_DRAIN_CANCELED"


class UnderflowError(PraxoError):
    code = "PLUGIN_INFLIGHT_UNDERFLOW"


class PolicyError(PraxoError):
    code = "POLICY_ERROR"


class PolicyDeniedError(PraxoError):
    code = "AGENT_POLICY_DENIED"


class PluginError(PraxoError):
    code = "PLUGIN_INVALID_MANIFEST"


class ToolNotFoundError(PraxoError):
    code = "TOOL_NOT_FOUND"
