module PraxoCore

include("Json.jl")
include("ToolCall.jl")
include("JsonSchema.jl")
include("Plugin.jl")
include("Errors.jl")
include("Models.jl")
include("Retriever.jl")
include("Delegation.jl")
include("Runtime.jl")
include("adapters/Harmovela.jl")
include("adapters/Otel.jl")
include("Middleware.jl")
include("Agent.jl")
include("adapters/OpenAICompatible.jl")
include("adapters/Anthropic.jl")
include("adapters/Gemini.jl")
include("adapters/Mcp.jl")

using .Models
using .Retrieval
using .Delegation
using .Runtime
using .Harmovela
using .Otel
using .Middleware
using .AgentRuntime
using .OpenAICompatible
using .Anthropic
using .Gemini
using .Mcp
using .Errors

export Json, ParsedToolCall, ToolCallParser
export ValidationError, JsonSchema
export PluginManifest, Plugin
export ContentBlock, ToolCall, Message, ToolSpec, Usage, Request, Response, message_dict
export Session, RunResult, MemoryRecord, PathGrant, Action, Decision, Event, Roles, StreamKinds
export AbstractSink, MultiSink, FilterSink, MemoryStore, CheckpointAllowlist, PathChecker
export HarmovelaSink, harmovela_sink
export OtelSink, otel_sink
export Document, FuncRetriever, Retriever, func_retriever, retrieve_documents
export SubagentRequest, SubagentResult, SubagentTask, SubagentRunner
export subagent_request, subagent_result, subagent_run
export ContextBudget, AgentOptions, Agent, StaticModel, FuncTool, ToolRegistry
export AbstractPolicy, AbstractModel, AbstractMiddleware, PiiRedactor, PraxoError
export OpenAICompatibleModel, openai_compatible
export AnthropicModel, anthropic, GeminiModel, gemini
export McpClient, mcp_client, mcp_list_tools, mcp_call_tool, mcp_close!
run_agent(args...) = AgentRuntime.run(args...)
export run_agent
export put!, search, register!, marshal, unmarshal, check, allowed
export estimate_tokens, truncate_to_tokens, compact, emit, RunState
export ToolSelector, StructuredOutput, CallLimitMiddleware, ToolSelectionMiddleware
export PiiMiddleware, ModelCall, ToolCallContext, ToolResult
export redact, redact_value, apply!, before_run!, before_model!, after_model!
export before_tool!, after_tool!, after_run!, fallback_model, generate, select

end