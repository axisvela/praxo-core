package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

const (
	tenantScope  = "acme"
	serviceScope = "service-100"
)

var (
	errTelemetryUnavailable = errors.New("telemetry unavailable")
	jsonObjectPattern       = regexp.MustCompile(`(?s)\{.*\}`)
)

type Stats struct {
	Reads      int `json:"reads"`
	Drafts     int `json:"drafts"`
	Executions int `json:"executions"`
}

type TraceStep struct {
	ToolCalls   []map[string]any `json:"tool_calls"`
	ToolResults []map[string]any `json:"tool_results"`
	ModelOutput map[string]any   `json:"model_output"`
}

type RunError struct {
	Code    string
	Message string
	Stats   Stats
	Trace   []TraceStep
}

func (e *RunError) Error() string {
	return e.Code + ": " + e.Message
}

type telemetryStore struct {
	mu      sync.Mutex
	reads   int
	failure bool
}

func newTelemetryStore() *telemetryStore {
	return &telemetryStore{}
}

func (t *telemetryStore) setFailure(value bool) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.failure = value
}

func (t *telemetryStore) readsCount() int {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.reads
}

func (t *telemetryStore) reset() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.reads = 0
}

func (t *telemetryStore) search(service string) (map[string]any, error) {
	t.mu.Lock()
	t.reads++
	failure := t.failure
	t.mu.Unlock()
	if failure {
		return nil, errTelemetryUnavailable
	}
	return map[string]any{
		"service":    service,
		"error_rate": 0.18,
		"latency_ms": 940,
		"suspect":    "checkout-api",
		"trace":      "trace-100",
		"source":     "telemetry_fixture",
	}, nil
}

type executor struct {
	mu         sync.Mutex
	executions int
}

func newExecutor() *executor {
	return &executor{}
}

func (e *executor) execute(service string) map[string]any {
	e.mu.Lock()
	e.executions++
	e.mu.Unlock()
	return map[string]any{"service": service, "status": "executed"}
}

func (e *executor) count() int {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.executions
}

func (e *executor) reset() {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.executions = 0
}

type funcTool struct {
	name        string
	description string
	parameters  map[string]any
	risk        string
	invoke      func(context.Context, map[string]any) (any, error)
}

func (t *funcTool) Name() string        { return t.name }
func (t *funcTool) Description() string { return t.description }
func (t *funcTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	return t.invoke(ctx, args)
}

func (t *funcTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        t.name,
		Description: t.description,
		Parameters:  t.parameters,
		Risk:        t.risk,
	}
}

type Runner struct {
	telemetry     *telemetryStore
	executor      *executor
	modelOverride model.Model
}

func NewRunner() *Runner {
	return &Runner{
		telemetry: newTelemetryStore(),
		executor:  newExecutor(),
	}
}

func (r *Runner) setModel(value model.Model) {
	r.modelOverride = value
}

func (r *Runner) Run(
	ctx context.Context,
	tenant string,
	service string,
	intent string,
) (map[string]any, Stats, []TraceStep, error) {
	var reads atomic.Int64
	var drafts atomic.Int64
	var executions atomic.Int64

	registry := tool.NewRegistry()
	registry.Register(&funcTool{
		name:        "search_signals",
		description: "Search fixed telemetry through the application-owned service.",
		parameters: map[string]any{
			"type":     "object",
			"required": []string{"service"},
			"properties": map[string]any{
				"service": map[string]any{"type": "string"},
			},
		},
		risk: "read",
		invoke: func(_ context.Context, args map[string]any) (any, error) {
			reads.Add(1)
			serviceArg, _ := args["service"].(string)
			return r.telemetry.search(serviceArg)
		},
	})
	registry.Register(&funcTool{
		name:        "draft_remediation",
		description: "Draft a model-written review-only remediation; never executes.",
		parameters: map[string]any{
			"type":     "object",
			"required": []string{"service", "action", "diagnosis", "rationale"},
			"properties": map[string]any{
				"service":   map[string]any{"type": "string"},
				"action":    map[string]any{"type": "string", "enum": []string{"review_remediation"}},
				"diagnosis": map[string]any{"type": "string"},
				"rationale": map[string]any{"type": "string"},
			},
		},
		risk: "write",
		invoke: func(_ context.Context, args map[string]any) (any, error) {
			drafts.Add(1)
			return map[string]any{
				"remediation_id":  "remediation-100",
				"service":         args["service"],
				"action":          args["action"],
				"diagnosis":       args["diagnosis"],
				"rationale":       args["rationale"],
				"status":          "draft_only",
				"review_required": true,
				"executions":      0,
			}, nil
		},
	})
	registry.Register(&funcTool{
		name:        "execute_remediation",
		description: "Would execute remediation. Always denied in the agent path.",
		parameters: map[string]any{
			"type":     "object",
			"required": []string{"service", "intent"},
			"properties": map[string]any{
				"service": map[string]any{"type": "string"},
				"intent":  map[string]any{"type": "string"},
			},
		},
		risk: "write",
		invoke: func(_ context.Context, args map[string]any) (any, error) {
			executions.Add(1)
			serviceArg, _ := args["service"].(string)
			return r.executor.execute(serviceArg), nil
		},
	})

	baseModel := model.Model(deterministicModel{service: service, intent: intent})
	mode := "deterministic"
	if r.modelOverride != nil {
		baseModel = r.modelOverride
		mode = "injected"
	} else if live, ok := liveModel(); ok {
		baseModel = live
		mode = "live"
	}

	tracing := &tracingModel{inner: baseModel}
	ag, err := agent.New(agent.Options{
		Model:            tracing,
		Tools:            registry,
		AllowedTools:     []string{"search_signals", "draft_remediation", "execute_remediation"},
		Policy:           opsPolicy(tenant),
		RequirePolicy:    true,
		RequireToolScope: true,
		MaxSteps:         4,
		MaxTokens:        60000,
		SystemPrompt: "You are an OTP operations copilot for tenant " + tenant + ". " +
			"The only authorized service id is service-100. Use that exact id in tool arguments; " +
			"display names such as 'checkout' are not service ids. Search telemetry, diagnose, and " +
			"draft a review-only remediation. Never execute remediation; return JSON with service, " +
			"signals, remediation, and executions.",
	})
	if err != nil {
		return nil, Stats{}, nil, &RunError{
			Code:    "AGENT_RUNTIME_ERROR",
			Message: err.Error(),
		}
	}

	result, runErr := ag.Run(ctx, agent.Session{
		ID:       "go-ai-ops-" + tenant + "-" + service,
		TenantID: tenant,
	}, intent)
	trace := tracing.Steps()
	stats := Stats{
		Reads:      int(reads.Load()),
		Drafts:     int(drafts.Load()),
		Executions: int(executions.Load()),
	}
	if runErr != nil {
		return nil, stats, trace, &RunError{
			Code:    classifyRunError(runErr),
			Message: runErr.Error(),
			Stats:   stats,
			Trace:   trace,
		}
	}

	report, parseErr := parseReport(result.Output)
	if parseErr != nil {
		code := "AGENT_INVALID_OUTPUT"
		if traceHasToolError(trace) {
			code = "TOOL_ERROR"
		}
		return nil, stats, trace, &RunError{
			Code:    code,
			Message: parseErr.Error(),
			Stats:   stats,
			Trace:   trace,
		}
	}
	report = normalizeReport(report, service, trace)
	if !validReport(report) {
		return nil, stats, trace, &RunError{
			Code:    "AGENT_INVALID_OUTPUT",
			Message: "agent did not return the required operations package",
			Stats:   stats,
			Trace:   trace,
		}
	}
	report["tenant"] = tenant
	report["model"] = mode
	report["agent_trace"] = trace
	return report, stats, trace, nil
}

func liveModel() (model.Model, bool) {
	baseURL := strings.TrimSpace(os.Getenv("PRAXO_BASE_URL"))
	name := strings.TrimSpace(os.Getenv("PRAXO_MODEL"))
	if baseURL == "" || name == "" {
		return nil, false
	}
	return openaicompat.Adapter{
		BaseURL: baseURL,
		APIKey:  os.Getenv("PRAXO_API_KEY"),
		Model:   name,
	}, true
}

type deterministicModel struct {
	service string
	intent  string
}

func (m deterministicModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	var toolMessages []model.Message
	for _, message := range req.Messages {
		if message.Role == model.RoleTool {
			toolMessages = append(toolMessages, message)
		}
	}
	if len(toolMessages) == 0 {
		if directExecution(m.intent) {
			return assistant("", []model.ToolCall{{
				ID:   "execute-1",
				Name: "execute_remediation",
				Arguments: map[string]any{
					"service": m.service,
					"intent":  m.intent,
				},
			}}), nil
		}
		return assistant("", []model.ToolCall{{
			ID:        "signals-1",
			Name:      "search_signals",
			Arguments: map[string]any{"service": m.service},
		}}), nil
	}

	first := parseJSONMap(toolMessages[0].Content)
	if code, ok := first["error"].(string); ok {
		return assistant(code, nil), nil
	}
	if len(toolMessages) == 1 {
		return assistant("", []model.ToolCall{{
			ID:   "remediation-1",
			Name: "draft_remediation",
			Arguments: map[string]any{
				"service":   m.service,
				"action":    "review_remediation",
				"diagnosis": "checkout-api shows elevated error rate and latency",
				"rationale": "error_rate 0.18 and latency_ms 940 exceed the review threshold",
			},
		}}), nil
	}

	last := parseJSONMap(toolMessages[len(toolMessages)-1].Content)
	report := map[string]any{
		"service":     m.service,
		"signals":     first,
		"remediation": last,
		"executions":  0,
	}
	raw, err := json.Marshal(report)
	if err != nil {
		return model.Response{}, err
	}
	return assistant(string(raw), nil), nil
}

func assistant(content string, calls []model.ToolCall) model.Response {
	return model.Response{Message: model.Message{
		Role:      model.RoleAssistant,
		Content:   content,
		ToolCalls: calls,
	}}
}

func directExecution(intent string) bool {
	lower := strings.ToLower(intent)
	return strings.Contains(lower, "execute remediation") || strings.Contains(lower, "remediate now")
}

func opsPolicy(tenant string) policy.Hook {
	return policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		if tenant != tenantScope {
			return policy.Decision{Reason: "tenant mismatch"}, nil
		}
		if action.Kind == "model.generate" {
			return policy.Decision{Allowed: true, Reason: "ops generation"}, nil
		}
		if action.Kind != "tool.invoke" {
			return policy.Decision{Reason: "unsupported action"}, nil
		}
		service, _ := action.Arguments["service"].(string)
		if action.ToolName == "execute_remediation" {
			return policy.Decision{Reason: "execution requires an approved host workflow"}, nil
		}
		if service != serviceScope {
			return policy.Decision{Reason: "only service-100 is in scope"}, nil
		}
		switch action.ToolName {
		case "search_signals":
			return policy.Decision{Allowed: true, Reason: "read-only telemetry"}, nil
		case "draft_remediation":
			actionName, _ := action.Arguments["action"].(string)
			diagnosis, _ := action.Arguments["diagnosis"].(string)
			rationale, _ := action.Arguments["rationale"].(string)
			if actionName == "review_remediation" && strings.TrimSpace(diagnosis) != "" && strings.TrimSpace(rationale) != "" {
				return policy.Decision{Allowed: true, Reason: "review-only remediation"}, nil
			}
			return policy.Decision{Reason: "review_remediation with diagnosis and rationale is required"}, nil
		default:
			return policy.Decision{Reason: "unsupported tool"}, nil
		}
	})
}

type tracingModel struct {
	inner model.Model
	mu    sync.Mutex
	steps []TraceStep
}

func (t *tracingModel) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	response, err := t.inner.Generate(ctx, req)
	step := traceStep(req, response, err)
	t.mu.Lock()
	t.steps = append(t.steps, step)
	t.mu.Unlock()
	return response, err
}

func (t *tracingModel) Steps() []TraceStep {
	t.mu.Lock()
	defer t.mu.Unlock()
	out := make([]TraceStep, len(t.steps))
	copy(out, t.steps)
	return out
}

func traceStep(req model.Request, response model.Response, err error) TraceStep {
	toolCalls := []map[string]any{}
	toolResults := []map[string]any{}
	for _, message := range req.Messages {
		for _, call := range message.ToolCalls {
			toolCalls = append(toolCalls, map[string]any{
				"name":      call.Name,
				"arguments": call.Arguments,
			})
		}
		if message.Role == model.RoleTool {
			toolResults = append(toolResults, map[string]any{
				"tool_id": message.ToolID,
				"content": message.Content,
			})
		}
	}
	output := map[string]any{}
	if err != nil {
		output["error"] = err.Error()
	} else {
		outputCalls := []map[string]any{}
		for _, call := range response.Message.ToolCalls {
			outputCalls = append(outputCalls, map[string]any{
				"name":      call.Name,
				"arguments": call.Arguments,
			})
		}
		output["content"] = truncate(response.Message.Content, 1000)
		output["tool_calls"] = outputCalls
	}
	return TraceStep{
		ToolCalls:   toolCalls,
		ToolResults: toolResults,
		ModelOutput: output,
	}
}

func truncate(value string, max int) string {
	if len(value) <= max {
		return value
	}
	return value[:max] + "..."
}

func parseReport(output string) (map[string]any, error) {
	var report map[string]any
	if err := json.Unmarshal([]byte(output), &report); err == nil && report != nil {
		return report, nil
	}
	match := jsonObjectPattern.FindString(output)
	if match != "" {
		if err := json.Unmarshal([]byte(match), &report); err == nil && report != nil {
			return report, nil
		}
	}
	return nil, errors.New("invalid report")
}

func normalizeReport(report map[string]any, service string, trace []TraceStep) map[string]any {
	payloads := []map[string]any{}
	for _, step := range trace {
		for _, result := range step.ToolResults {
			content, _ := result["content"].(string)
			if payload := parseJSONMap(content); payload != nil {
				payloads = append(payloads, payload)
			}
		}
	}
	remediation := findPayload(payloads, "remediation_id")
	signals := findPayload(payloads, "suspect")
	taxonomy := findPayload(payloads, "tags")
	review := findPayload(payloads, "review_id")
	report["service"] = service
	report["executions"] = 0
	if remediation != nil {
		report["remediation"] = remediation
	}
	if signals != nil {
		report["signals"] = signals
	}
	if taxonomy != nil {
		report["taxonomy"] = taxonomy
	}
	if review != nil {
		report["review"] = review
	}
	return report
}

func parseJSONMap(content string) map[string]any {
	var value map[string]any
	if json.Unmarshal([]byte(content), &value) == nil {
		return value
	}
	return nil
}

func findPayload(payloads []map[string]any, key string) map[string]any {
	for _, payload := range payloads {
		if _, ok := payload[key]; ok {
			return payload
		}
	}
	return nil
}

func validReport(report map[string]any) bool {
	for _, key := range []string{"service", "signals", "remediation", "executions"} {
		if _, ok := report[key]; !ok {
			return false
		}
	}
	return zero(report["executions"])
}

func zero(value any) bool {
	switch typed := value.(type) {
	case int:
		return typed == 0
	case int64:
		return typed == 0
	case float64:
		return typed == 0
	case json.Number:
		return typed.String() == "0"
	default:
		return false
	}
}

func classifyRunError(err error) string {
	if errors.Is(err, errTelemetryUnavailable) {
		return "TOOL_ERROR"
	}
	message := strings.ToLower(err.Error())
	if strings.Contains(message, "policy") || strings.Contains(message, "denied") {
		return "AGENT_POLICY_DENIED"
	}
	if strings.Contains(message, "tool") {
		return "TOOL_ERROR"
	}
	return "AGENT_RUNTIME_ERROR"
}

func traceHasToolError(trace []TraceStep) bool {
	for _, step := range trace {
		for _, result := range step.ToolResults {
			content, _ := result["content"].(string)
			if payload := parseJSONMap(content); payload != nil {
				if _, ok := payload["error"]; ok {
					return true
				}
			}
		}
	}
	return false
}

func errorJSON(err error) map[string]any {
	var runErr *RunError
	if errors.As(err, &runErr) {
		return map[string]any{
			"error":   runErr.Code,
			"message": runErr.Message,
			"agent":   runErr.Stats,
		}
	}
	return map[string]any{
		"error":   "AGENT_RUNTIME_ERROR",
		"message": fmt.Sprint(err),
		"agent":   Stats{},
	}
}
