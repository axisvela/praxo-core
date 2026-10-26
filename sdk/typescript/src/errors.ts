export class PraxoError extends Error {
  readonly code: string;

  constructor(message: string, code = "PRAXO_ERROR") {
    super(message);
    this.name = "PraxoError";
    this.code = code;
  }
}

export class MaxStepsError extends PraxoError {
  constructor(message = "agent: max steps exceeded") {
    super(message, "AGENT_MAX_STEPS");
    this.name = "MaxStepsError";
  }
}

export class MaxTokensError extends PraxoError {
  constructor(message = "agent: max tokens exceeded") {
    super(message, "AGENT_MAX_TOKENS");
    this.name = "MaxTokensError";
  }
}

export class ContextBudgetError extends PraxoError {
  constructor(message = "agent: context budget exceeded") {
    super(message, "AGENT_CONTEXT_BUDGET");
    this.name = "ContextBudgetError";
  }
}

export class ModelCallLimitError extends PraxoError {
  constructor(message = "agent: model call limit exceeded") {
    super(message, "AGENT_MODEL_CALL_LIMIT");
    this.name = "ModelCallLimitError";
  }
}

export class ToolCallLimitError extends PraxoError {
  constructor(message = "agent: tool call limit exceeded") {
    super(message, "AGENT_TOOL_CALL_LIMIT");
    this.name = "ToolCallLimitError";
  }
}

export class ToolNotSelectedError extends PraxoError {
  constructor(message = "agent: tool not selected") {
    super(message, "AGENT_TOOL_NOT_SELECTED");
    this.name = "ToolNotSelectedError";
  }
}

export class StructuredOutputError extends PraxoError {
  constructor(message = "agent: structured output validation failed") {
    super(message, "AGENT_STRUCTURED_OUTPUT");
    this.name = "StructuredOutputError";
  }
}

export class TypeNotAllowedError extends PraxoError {
  constructor(message: string) {
    super(message, "CHECKPOINT_TYPE_NOT_ALLOWED");
    this.name = "TypeNotAllowedError";
  }
}

export class CheckpointError extends PraxoError {
  constructor(message: string) {
    super(message, "CHECKPOINT_ERROR");
    this.name = "CheckpointError";
  }
}

export class PluginError extends PraxoError {
  constructor(message: string) {
    super(message, "PLUGIN_INVALID_MANIFEST");
    this.name = "PluginError";
  }
}

export class AbortError extends PraxoError {
  constructor(message = "agent: aborted") {
    super(message, "AGENT_ABORTED");
    this.name = "AbortError";
  }
}

export class PolicyError extends PraxoError {
  constructor(message: string) {
    super(message, "POLICY_ERROR");
    this.name = "PolicyError";
  }
}

export class PolicyDeniedError extends PraxoError {
  constructor(message: string) {
    super(message, "AGENT_POLICY_DENIED");
    this.name = "PolicyDeniedError";
  }
}

export class ToolNotFoundError extends PraxoError {
  constructor(message: string) {
    super(message, "TOOL_NOT_FOUND");
    this.name = "ToolNotFoundError";
  }
}
