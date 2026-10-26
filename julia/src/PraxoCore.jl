module PraxoCore

include("Json.jl")
include("ToolCall.jl")
include("JsonSchema.jl")
include("Plugin.jl")
include("Errors.jl")
include("Models.jl")
include("Runtime.jl")
include("Middleware.jl")
include("Agent.jl")

using .Models
using .Runtime
using .Middleware
using .AgentRuntime
using .Errors

export Json, ParsedToolCall, ToolCallParser
export ValidationError, JsonSchema
export PluginManifest, Plugin
export ContentBlock, ToolCall, Message, ToolSpec, Usage, Request, Response, message_dict
export Session, RunResult, MemoryRecord, PathGrant, Action, Decision, Event, Roles, StreamKinds
export AbstractSink, MultiSink, FilterSink, MemoryStore, CheckpointAllowlist, PathChecker
export ContextBudget, AgentOptions, Agent, StaticModel, FuncTool, ToolRegistry
export AbstractPolicy, AbstractModel, AbstractMiddleware, PiiRedactor, PraxoError
run_agent(args...) = AgentRuntime.run(args...)
export run_agent
export put!, search, register!, marshal, unmarshal, check, allowed
export estimate_tokens, truncate_to_tokens, compact, emit, RunState
export ToolSelector, StructuredOutput, CallLimitMiddleware, ToolSelectionMiddleware
export PiiMiddleware, ModelCall, ToolCallContext, ToolResult
export redact, redact_value, apply!, before_run!, before_model!, after_model!
export before_tool!, after_tool!, after_run!, fallback_model, generate, select

end