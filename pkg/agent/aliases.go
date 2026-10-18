package agent

import (
	agentcontext "github.com/axisvela/praxo-core/pkg/agent/context"
	agentdelegation "github.com/axisvela/praxo-core/pkg/agent/delegation"
	agentevaluation "github.com/axisvela/praxo-core/pkg/agent/evaluation"
	agenthitl "github.com/axisvela/praxo-core/pkg/agent/hitl"
	agentmiddleware "github.com/axisvela/praxo-core/pkg/agent/middleware"
	agentstream "github.com/axisvela/praxo-core/pkg/agent/stream"
	agenttypes "github.com/axisvela/praxo-core/pkg/agent/types"
	"github.com/axisvela/praxo-core/pkg/model"
)

// Shared run-state contracts.
type (
	Session         = agenttypes.Session
	Result          = agenttypes.Result
	Middleware      = agenttypes.Middleware
	RunState        = agenttypes.RunState
	ModelCall       = agenttypes.ModelCall
	ToolCall        = agenttypes.ToolCall
	ToolResult      = agenttypes.ToolResult
	ModelMiddleware = agenttypes.ModelMiddleware
	RetryPolicy     = agenttypes.RetryPolicy
	Hooks           = agenttypes.Hooks
	SessionStore    = agenttypes.SessionStore
)

// Stream projections.
type (
	StreamKind = agentstream.StreamKind
	StreamPart = agentstream.StreamPart
)

const (
	StreamValues     = agentstream.StreamValues
	StreamUpdates    = agentstream.StreamUpdates
	StreamMessages   = agentstream.StreamMessages
	StreamTasks      = agentstream.StreamTasks
	StreamDebug      = agentstream.StreamDebug
	StreamCheckpoint = agentstream.StreamCheckpoint
)

// Human-in-the-loop decisions.
type (
	Interrupt         = agenthitl.Interrupt
	InterruptAction   = agenthitl.InterruptAction
	InterruptDecision = agenthitl.InterruptDecision
	InterruptHandler  = agenthitl.InterruptHandler
)

const (
	InterruptApprove = agenthitl.InterruptApprove
	InterruptEdit    = agenthitl.InterruptEdit
	InterruptReject  = agenthitl.InterruptReject
	InterruptRespond = agenthitl.InterruptRespond
)

// ErrInterruptDecisionInvalid reports an unsupported or incomplete decision.
var ErrInterruptDecisionInvalid = agenthitl.ErrInterruptDecisionInvalid

// Evaluation contracts.
type (
	Criterion  = agentevaluation.Criterion
	Rubric     = agentevaluation.Rubric
	Evaluation = agentevaluation.Evaluation
	Evaluator  = agentevaluation.Evaluator
)

// ErrRubricFailed reports a final output below the rubric pass score.
var ErrRubricFailed = agentevaluation.ErrRubricFailed

// RubricMiddleware evaluates a completed run and fails it when the rubric does
// not pass.
func RubricMiddleware(rubric Rubric, evaluator Evaluator, onEvaluation func(Evaluation) error) Middleware {
	return agentevaluation.RubricMiddleware(rubric, evaluator, onEvaluation)
}

// Context contracts.
type (
	ContextBudget    = agentcontext.ContextBudget
	ContextCompactor = agentcontext.ContextCompactor
	ModelSummarizer  = agentcontext.ModelSummarizer
	Offloader        = agentcontext.Offloader
	OffloadFunc      = agentcontext.OffloadFunc
)

const MaxAgentsMDBytes = agentcontext.MaxAgentsMDBytes

// ErrContextBudget is returned when the prompt cannot fit the budget.
var ErrContextBudget = agentcontext.ErrContextBudget

// LoadAgentsMD loads bounded AGENTS.md memory files.
func LoadAgentsMD(paths ...string) (string, error) {
	return agentcontext.LoadAgentsMD(paths...)
}

// EstimateTokens returns a rough prompt-size estimate.
func EstimateTokens(messages []model.Message) int {
	return agentcontext.EstimateTokens(messages)
}

func estimateTokens(messages []model.Message) int {
	return EstimateTokens(messages)
}

// Delegation contracts.
type (
	SubagentMode       = agentdelegation.SubagentMode
	SubagentStatus     = agentdelegation.SubagentStatus
	SubagentRequest    = agentdelegation.SubagentRequest
	SubagentResult     = agentdelegation.SubagentResult
	SubagentRunner     = agentdelegation.SubagentRunner
	ControllableRunner = agentdelegation.ControllableRunner
	SubagentTask       = agentdelegation.SubagentTask
	SubagentManager    = agentdelegation.SubagentManager
)

const (
	SubagentIsolated  = agentdelegation.SubagentIsolated
	SubagentFork      = agentdelegation.SubagentFork
	SubagentQueued    = agentdelegation.SubagentQueued
	SubagentRunning   = agentdelegation.SubagentRunning
	SubagentCompleted = agentdelegation.SubagentCompleted
	SubagentFailed    = agentdelegation.SubagentFailed
	SubagentCanceled  = agentdelegation.SubagentCanceled
)

// ErrSubagentUpdateUnsupported reports that a runner cannot accept an update.
var ErrSubagentUpdateUnsupported = agentdelegation.ErrSubagentUpdateUnsupported

// NewSubagentManager returns an asynchronous subagent manager.
func NewSubagentManager(runner SubagentRunner) *SubagentManager {
	return agentdelegation.NewSubagentManager(runner)
}

// Agent middleware contracts.
type (
	PIIRule                  = agentmiddleware.PIIRule
	PIIRedactor              = agentmiddleware.PIIRedactor
	StructuredOutputStrategy = agentmiddleware.StructuredOutputStrategy
	StructuredOutput         = agentmiddleware.StructuredOutput
	ToolSelector             = agentmiddleware.ToolSelector
	ModelToolSelector        = agentmiddleware.ModelToolSelector
	ContextEdit              = agentmiddleware.ContextEdit
	TodoStatus               = agentmiddleware.TodoStatus
	TodoItem                 = agentmiddleware.TodoItem
	TodoList                 = agentmiddleware.TodoList
	TodoTool                 = agentmiddleware.TodoTool
)

const (
	StructuredOutputAuto     = agentmiddleware.StructuredOutputAuto
	StructuredOutputProvider = agentmiddleware.StructuredOutputProvider
	StructuredOutputTool     = agentmiddleware.StructuredOutputTool
	TodoPending              = agentmiddleware.TodoPending
	TodoInProgress           = agentmiddleware.TodoInProgress
	TodoCompleted            = agentmiddleware.TodoCompleted
	TodoCancelled            = agentmiddleware.TodoCancelled
)

var (
	// ErrModelCallLimit reports an exhausted model-call budget.
	ErrModelCallLimit = agentmiddleware.ErrModelCallLimit
	// ErrToolCallLimit reports an exhausted tool-call budget.
	ErrToolCallLimit = agentmiddleware.ErrToolCallLimit
	// ErrStructuredOutput reports a schema validation failure.
	ErrStructuredOutput = agentmiddleware.ErrStructuredOutput
	// ErrToolNotSelected reports a call to an unselected tool.
	ErrToolNotSelected = agentmiddleware.ErrToolNotSelected
)

// NewPIIRule compiles one redaction rule.
func NewPIIRule(name, pattern, replacement string) PIIRule {
	return agentmiddleware.NewPIIRule(name, pattern, replacement)
}

// NewPIIRedactor returns a redactor with the supplied rules.
func NewPIIRedactor(rules ...PIIRule) PIIRedactor {
	return agentmiddleware.NewPIIRedactor(rules...)
}

// DefaultPIIRules returns the built-in redaction rules.
func DefaultPIIRules() []PIIRule {
	return agentmiddleware.DefaultPIIRules()
}

// CallLimitMiddleware bounds model and tool calls per run.
func CallLimitMiddleware(modelLimit, toolLimit int) Middleware {
	return agentmiddleware.CallLimitMiddleware(modelLimit, toolLimit)
}

// PIIMiddleware redacts model-bound messages and tool results.
func PIIMiddleware(redactor PIIRedactor) Middleware {
	return agentmiddleware.PIIMiddleware(redactor)
}

// ToolSelectionMiddleware narrows advertised tools per run.
func ToolSelectionMiddleware(selector ToolSelector) Middleware {
	return agentmiddleware.ToolSelectionMiddleware(selector)
}

// FallbackModel retries a failed primary model call on a fallback model.
func FallbackModel(fallback model.Model) ModelMiddleware {
	return agentmiddleware.FallbackModel(fallback)
}

// ContextEditingMiddleware clears old tool results before model calls.
func ContextEditingMiddleware(edit ContextEdit) Middleware {
	return agentmiddleware.ContextEditingMiddleware(edit)
}

// NewTodoList returns an empty todo list.
func NewTodoList() *TodoList {
	return agentmiddleware.NewTodoList()
}

// TodoMiddleware injects the current todo list before model calls.
func TodoMiddleware(list *TodoList) Middleware {
	return agentmiddleware.TodoMiddleware(list)
}
